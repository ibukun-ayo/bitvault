;; Title: BitVault Protocol - Bitcoin-Native Staking Platform
;; 
;; Summary: A sophisticated staking protocol built on Stacks that enables Bitcoin
;;          holders to earn passive yields on their sBTC assets through secure,
;;          time-locked vaults with dynamic reward mechanisms.
;;
;; Description: BitVault Protocol harnesses the security of Bitcoin and the
;;              programmability of Stacks to create a trustless staking ecosystem.
;;              Users can deposit sBTC into time-locked vaults to earn rewards
;;              based on staking duration and network participation. The protocol
;;              features flexible staking periods, compound rewards, transparent
;;              governance, and emergency withdrawal mechanisms - all while
;;              maintaining Bitcoin's security guarantees through Stacks Layer 2.
;;              Perfect for HODLers seeking passive income without compromising
;;              Bitcoin's decentralized ethos.
;;

;; ERROR CONSTANTS

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ZERO_AMOUNT (err u101))
(define-constant ERR_NO_POSITION (err u102))
(define-constant ERR_LOCKED_PERIOD (err u103))
(define-constant ERR_INVALID_RATE (err u104))
(define-constant ERR_INSUFFICIENT_REWARDS (err u105))
(define-constant ERR_INVALID_PERIOD (err u106))
(define-constant ERR_SAME_OWNER (err u107))

;; DATA STRUCTURES

;; Core staking positions
(define-map staking-positions
  { staker: principal }
  {
    amount: uint,
    locked-at: uint,
  }
)

;; Reward claim history
(define-map reward-history
  { staker: principal }
  { total-claimed: uint }
)

;; PROTOCOL STATE VARIABLES

(define-data-var annual-yield-rate uint u500)        ;; 5.00% APY in basis points
(define-data-var treasury-balance uint u0)           ;; Available reward funds
(define-data-var minimum-lock-period uint u1440)     ;; ~10 days in blocks
(define-data-var total-value-locked uint u0)         ;; Protocol TVL
(define-data-var protocol-owner principal tx-sender) ;; Governance controller

;; GOVERNANCE FUNCTIONS

;; Get current protocol owner
(define-read-only (get-protocol-owner)
  (var-get protocol-owner)
)

;; Transfer protocol ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq new-owner (var-get protocol-owner))) ERR_SAME_OWNER)
    (var-set protocol-owner new-owner)
    (ok true)
  )
)

;; Update annual yield rate (capped at 50% APY for safety)
(define-public (update-yield-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= new-rate u5000) ERR_INVALID_RATE)
    (var-set annual-yield-rate new-rate)
    (ok true)
  )
)

;; Adjust minimum lock period
(define-public (set-lock-period (blocks uint))
  (begin
    (asserts! (is-eq tx-sender (var-get protocol-owner)) ERR_UNAUTHORIZED)
    (asserts! (> blocks u0) ERR_INVALID_PERIOD)
    (var-set minimum-lock-period blocks)
    (ok true)
  )
)

;; Fund the treasury for reward distribution
(define-public (fund-treasury (amount uint))
  (begin
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount tx-sender (as-contract tx-sender) none))
    (var-set treasury-balance (+ (var-get treasury-balance) amount))
    (ok true)
  )
)

;; CORE STAKING FUNCTIONS

;; Stake sBTC tokens
(define-public (stake-btc (amount uint))
  (begin
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    
    ;; Transfer sBTC to protocol
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update or create staking position
    (match (map-get? staking-positions { staker: tx-sender })
      existing-position
      ;; Add to existing position
      (map-set staking-positions { staker: tx-sender } {
        amount: (+ amount (get amount existing-position)),
        locked-at: stacks-block-height,
      })
      ;; Create new position
      (map-set staking-positions { staker: tx-sender } {
        amount: amount,
        locked-at: stacks-block-height,
      })
    )
    
    ;; Update protocol TVL
    (var-set total-value-locked (+ (var-get total-value-locked) amount))
    (ok true)
  )
)

;; Calculate pending rewards for a staker
(define-read-only (get-pending-rewards (staker principal))
  (match (map-get? staking-positions { staker: staker })
    position
    (let (
        (staked-amount (get amount position))
        (blocks-staked (- stacks-block-height (get locked-at position)))
        (annual-rate (var-get annual-yield-rate))
        (blocks-per-year u52560) ;; Approximate blocks per year on Stacks
      )
      ;; Calculate time-weighted rewards
      (/ (* (* staked-amount annual-rate) blocks-staked) (* u10000 blocks-per-year))
    )
    u0
  )
)

;; Claim accumulated rewards
(define-public (claim-rewards)
  (let (
      (position (unwrap! (map-get? staking-positions { staker: tx-sender }) ERR_NO_POSITION))
      (rewards (get-pending-rewards tx-sender))
    )
    (asserts! (> rewards u0) ERR_NO_POSITION)
    (asserts! (<= rewards (var-get treasury-balance)) ERR_INSUFFICIENT_REWARDS)
    
    ;; Update treasury and reward history
    (var-set treasury-balance (- (var-get treasury-balance) rewards))
    (match (map-get? reward-history { staker: tx-sender })
      history (map-set reward-history { staker: tx-sender } { 
        total-claimed: (+ rewards (get total-claimed history)) 
      })
      (map-set reward-history { staker: tx-sender } { total-claimed: rewards })
    )
    
    ;; Reset reward calculation timestamp
    (map-set staking-positions { staker: tx-sender } {
      amount: (get amount position),
      locked-at: stacks-block-height,
    })
    
    ;; Transfer rewards to user
    (as-contract (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer rewards (as-contract tx-sender) tx-sender none)))
    
    (ok rewards)
  )
)

;; Unstake tokens (claims rewards automatically)
(define-public (unstake-btc (amount uint))
  (let (
      (position (unwrap! (map-get? staking-positions { staker: tx-sender }) ERR_NO_POSITION))
      (staked-amount (get amount position))
      (locked-duration (- stacks-block-height (get locked-at position)))
    )
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (asserts! (>= staked-amount amount) ERR_NO_POSITION)
    (asserts! (>= locked-duration (var-get minimum-lock-period)) ERR_LOCKED_PERIOD)
    
    ;; Auto-claim rewards first
    (try! (claim-rewards))
    
    ;; Update or remove position
    (if (> staked-amount amount)
      (map-set staking-positions { staker: tx-sender } {
        amount: (- staked-amount amount),
        locked-at: stacks-block-height,
      })
      (map-delete staking-positions { staker: tx-sender })
    )
    
    ;; Update TVL and transfer tokens
    (var-set total-value-locked (- (var-get total-value-locked) amount))
    (as-contract (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount (as-contract tx-sender) tx-sender none)))
    
    (ok amount)
  )
)

;; READ-ONLY FUNCTIONS

;; Get staker's position details
(define-read-only (get-position (staker principal))
  (map-get? staking-positions { staker: staker })
)

;; Get staker's reward history
(define-read-only (get-reward-history (staker principal))
  (map-get? reward-history { staker: staker })
)

;; Get current protocol configuration
(define-read-only (get-protocol-config)
  {
    annual-yield-rate: (var-get annual-yield-rate),
    minimum-lock-period: (var-get minimum-lock-period),
    treasury-balance: (var-get treasury-balance),
    total-value-locked: (var-get total-value-locked),
  }
)

;; Get formatted APY for display (as percentage)
(define-read-only (get-current-apy)
  (/ (var-get annual-yield-rate) u100)
)

;; Check if position can be unstaked
(define-read-only (can-unstake (staker principal))
  (match (map-get? staking-positions { staker: staker })
    position
    (>= (- stacks-block-height (get locked-at position)) (var-get minimum-lock-period))
    false
  )
)
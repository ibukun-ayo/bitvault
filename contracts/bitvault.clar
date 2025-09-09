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
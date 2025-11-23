;; ------------------------------------------------------------
;; Contract: insurance_pool
;; Purpose: Autonomous insurance pool with oracle-verified payouts.
;; Users stake STX -> build pool -> oracle triggers insurance event ->
;; payouts are distributed proportionally to stake weight.
;; ------------------------------------------------------------

;; -------------------------
;; Data Variables
;; -------------------------

;; Oracle allowed to trigger payouts
(define-data-var oracle principal tx-sender)

;; Total STX staked across all users
(define-data-var total-staked uint u0)

;; Whether a payout was executed (prevents double-claim events)
(define-data-var event-triggered bool false)

;; Mapping of staker -> amount staked
(define-map stakes
  { user: principal }
  { amount: uint })

;; Mapping of staker -> whether they already claimed payout
(define-map claimed
  { user: principal }
  { done: bool })


;; -------------------------
;; Error Codes
;; -------------------------

(define-constant ERR-NOT-ORACLE     (err u100))
(define-constant ERR-NO-STAKE       (err u101))
(define-constant ERR-ALREADY-CLAIMED (err u102))
(define-constant ERR-EVENT-NOT-TRIGGERED (err u103))
(define-constant ERR-EVENT-ALREADY  (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))


;; -------------------------
;; Helpers
;; -------------------------

(define-read-only (is-oracle (sender principal))
  (is-eq sender (var-get oracle))
)

(define-read-only (get-stake (user principal))
  (default-to { amount: u0 } (map-get? stakes { user: user }))
)

(define-read-only (has-claimed (user principal))
  (default-to { done: false } (map-get? claimed { user: user }))
)


;; -------------------------
;; Owner: Set Oracle
;; -------------------------

(define-public (set-oracle (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle)) ERR-NOT-ORACLE)
    (asserts! (not (is-eq new-oracle tx-sender)) ERR-INVALID-AMOUNT)
    (var-set oracle new-oracle)
    (ok true)
  )
)


;; -------------------------
;; Stake STX
;; -------------------------

(define-public (stake (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)

    ;; Transfer STX into pool (contract-owned)
    (match (stx-transfer? amount tx-sender (as-contract tx-sender))
      success
        (let
          (
            (prev (get-stake tx-sender))
            (new (+ (get amount prev) amount))
          )
          (begin
            (map-set stakes { user: tx-sender } { amount: new })
            (var-set total-staked (+ (var-get total-staked) amount))
            (ok new)
          )
        )
      error (err u200)
    )
  )
)


;; -------------------------
;; Oracle triggers insurance event
;; Locks the pool and enables claims
;; -------------------------

(define-public (trigger-event)
  (begin
    (asserts! (is-oracle tx-sender) ERR-NOT-ORACLE)
    (asserts! (not (var-get event-triggered)) ERR-EVENT-ALREADY)

    (var-set event-triggered true)
    (ok true)
  )
)


;; -------------------------
;; User claims payout
;; Payout = (user stake / total stake) * pool-balance
;; -------------------------

(define-public (claim)
  (begin
    (asserts! (var-get event-triggered) ERR-EVENT-NOT-TRIGGERED)

    (let
      (
        (info (get-stake tx-sender))
        (already (has-claimed tx-sender))
      )

      (begin
        (asserts! (> (get amount info) u0) ERR-NO-STAKE)
        (asserts! (not (get done already)) ERR-ALREADY-CLAIMED)

        (let
          (
            (user-stake (get amount info))
            (total (var-get total-staked))
            (pool-balance (stx-get-balance (as-contract tx-sender)))
            (payout (/ (* user-stake pool-balance) total))
          )

          (begin
            ;; Mark claimed
            (map-set claimed { user: tx-sender } { done: true })

            ;; Send payout
            (as-contract
              (match (stx-transfer? payout (as-contract tx-sender) tx-sender)
                success (ok payout)
                error   (err u201)
              )
            )
          )
        )
      )
    )
  )
)


;; -------------------------
;; Read-Only Views
;; -------------------------

(define-read-only (get-user-stake (user principal))
  (get amount (get-stake user))
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (event-status)
  (var-get event-triggered)
)


;; SecureEstate: A Secure Escrow Smart Contract for Real Estate Transactions
;; Version: 1.0
;; Author: Your Organization
;; License: MIT

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-INITIALIZED (err u101))
(define-constant ERR-NOT-INITIALIZED (err u102))
(define-constant ERR-WRONG-PRICE (err u103))
(define-constant ERR-ALREADY-PAID (err u104))
(define-constant ERR-NOT-PAID (err u105))
(define-constant ERR-INVALID-STATE (err u106))

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var seller principal tx-sender)
(define-data-var buyer (optional principal) none)
(define-data-var property-price uint u0)
(define-data-var deposit-amount uint u0)
(define-data-var is-initialized bool false)
(define-data-var is-paid bool false)
(define-data-var is-completed bool false)

;; Data Maps
(define-map transaction-details
  { tx-id: uint }
  {
    amount: uint,
    timestamp: uint,
    status: (string-ascii 20)
  }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-seller)
  (is-eq tx-sender (var-get seller))
)

(define-private (is-buyer)
  (match (var-get buyer)
    buyer-principal (is-eq tx-sender buyer-principal)
    false
  )
)

;; Public Functions
(define-public (initialize-escrow (new-seller principal) (new-buyer principal) (price uint))
  (begin
    (asserts! (not (var-get is-initialized)) ERR-ALREADY-INITIALIZED)
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> price u0) ERR-WRONG-PRICE)
    
    (var-set seller new-seller)
    (var-set buyer (some new-buyer))
    (var-set property-price price)
    (var-set deposit-amount (/ (* price u10) u100)) ;; 10% deposit
    (var-set is-initialized true)
    (ok true)
  )
)

(define-public (pay-deposit)
  (let ((deposit (var-get deposit-amount)))
    (begin
      (asserts! (var-get is-initialized) ERR-NOT-INITIALIZED)
      (asserts! (is-buyer) ERR-NOT-AUTHORIZED)
      (asserts! (not (var-get is-paid)) ERR-ALREADY-PAID)
      
      (try! (stx-transfer? deposit tx-sender (as-contract tx-sender)))
      (var-set is-paid true)
      (map-set transaction-details {tx-id: u1}
        {
          amount: deposit,
          timestamp: block-height,
          status: "DEPOSITED"
        }
      )
      (ok true)
    )
  )
)

(define-public (pay-remaining)
  (let ((remaining (- (var-get property-price) (var-get deposit-amount))))
    (begin
      (asserts! (var-get is-initialized) ERR-NOT-INITIALIZED)
      (asserts! (is-buyer) ERR-NOT-AUTHORIZED)
      (asserts! (var-get is-paid) ERR-NOT-PAID)
      
      (try! (stx-transfer? remaining tx-sender (var-get seller)))
      (var-set is-completed true)
      (map-set transaction-details {tx-id: u2}
        {
          amount: remaining,
          timestamp: block-height,
          status: "COMPLETED"
        }
      )
      (ok true)
    )
  )
)

(define-public (refund-deposit)
  (begin
    (asserts! (var-get is-initialized) ERR-NOT-INITIALIZED)
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (var-get is-paid) ERR-NOT-PAID)
    (asserts! (not (var-get is-completed)) ERR-INVALID-STATE)
    
    (match (var-get buyer)
      buyer-principal
      (begin
        (try! (as-contract (stx-transfer? (var-get deposit-amount) tx-sender buyer-principal)))
        (var-set is-paid false)
        (map-set transaction-details {tx-id: u3}
          {
            amount: (var-get deposit-amount),
            timestamp: block-height,
            status: "REFUNDED"
          }
        )
        (ok true)
      )
      (err ERR-NOT-INITIALIZED)
    )
  )
)

;; Read-only Functions
(define-read-only (get-escrow-details)
  {
    seller: (var-get seller),
    buyer: (var-get buyer),
    price: (var-get property-price),
    deposit: (var-get deposit-amount),
    is-initialized: (var-get is-initialized),
    is-paid: (var-get is-paid),
    is-completed: (var-get is-completed)
  }
)

(define-read-only (get-transaction-detail (tx-id uint))
  (map-get? transaction-details {tx-id: tx-id})
)
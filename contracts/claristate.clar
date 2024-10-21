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
(define-constant ERR-INVALID-SELLER (err u107))
(define-constant ERR-INVALID-BUYER (err u108))
(define-constant ERR-INVALID-PRINCIPAL (err u109))
(define-constant CONTRACT-OWNER tx-sender)

;; Data Variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var seller principal CONTRACT-OWNER)
(define-data-var buyer (optional principal) none)
(define-data-var property-price uint u0)
(define-data-var deposit-amount uint u0)
(define-data-var is-initialized bool false)
(define-data-var is-paid bool false)
(define-data-var is-completed bool false)

;; Data Maps
(define-map allowed-principals principal bool)
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

(define-private (check-principal (principal-to-check principal))
  (begin
    (asserts! (not (is-eq principal-to-check CONTRACT-OWNER)) ERR-INVALID-PRINCIPAL)
    (asserts! (not (is-eq principal-to-check tx-sender)) ERR-INVALID-PRINCIPAL)
    (ok true)
  )
)

(define-private (validate-and-store-principal (principal-to-store principal))
  (begin
    (try! (check-principal principal-to-store))
    (map-set allowed-principals principal-to-store true)
    (ok true)
  )
)

;; Public Functions
(define-public (initialize-escrow (new-seller principal) (new-buyer principal) (price uint))
  (begin
    (asserts! (not (var-get is-initialized)) ERR-ALREADY-INITIALIZED)
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> price u0) ERR-WRONG-PRICE)
    (asserts! (not (is-eq new-seller new-buyer)) ERR-INVALID-PRINCIPAL)
    
    ;; Validate and store principals
    (try! (validate-and-store-principal new-seller))
    (try! (validate-and-store-principal new-buyer))
    
    ;; Verify principals are allowed
    (asserts! (is-some (map-get? allowed-principals new-seller)) ERR-INVALID-SELLER)
    (asserts! (is-some (map-get? allowed-principals new-buyer)) ERR-INVALID-BUYER)
    
    ;; Only set variables after all checks pass
    (var-set seller new-seller)
    (var-set buyer (some new-buyer))
    (var-set property-price price)
    (var-set deposit-amount (/ (* price u10) u100))
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
  (let ((buyer-principal (unwrap! (var-get buyer) ERR-NOT-INITIALIZED)))
    (begin
      (asserts! (var-get is-initialized) ERR-NOT-INITIALIZED)
      (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
      (asserts! (var-get is-paid) ERR-NOT-PAID)
      (asserts! (not (var-get is-completed)) ERR-INVALID-STATE)
      
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

(define-read-only (is-allowed-principal (principal-to-check principal))
  (default-to false (map-get? allowed-principals principal-to-check))
)
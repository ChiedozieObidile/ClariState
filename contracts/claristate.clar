;; SecureEstate: A Secure Escrow Smart Contract for Real Estate Transactions
;; Error codes
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-init (err u101))
(define-constant err-not-init (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-already-paid (err u104))
(define-constant err-not-paid (err u105))
(define-constant err-invalid-state (err u106))
(define-constant err-same-parties (err u107))

;; Principal storage
(define-data-var escrow-owner principal contract-owner)
(define-data-var property-seller principal contract-owner)
(define-data-var property-buyer (optional principal) none)

;; State storage
(define-data-var init-status bool false)
(define-data-var payment-status bool false)
(define-data-var completion-status bool false)

;; Amount storage
(define-data-var sale-price uint u0)
(define-data-var escrow-amount uint u0)

;; Transaction recording
(define-map escrow-ledger
    uint
    {
        tx-amount: uint,
        block: uint,
        action: (string-ascii 10)
    }
)

;; Check if caller is contract owner
(define-private (is-owner)
    (is-eq tx-sender (var-get escrow-owner)))

;; Check if caller is buyer
(define-private (is-buyer)
    (match (var-get property-buyer)
        buyer (is-eq tx-sender buyer)
        false))

;; Initialize escrow contract
(define-public (init-escrow (seller principal) (buyer principal) (price uint))
    (begin
        (asserts! (is-owner) err-owner-only)
        (asserts! (not (var-get init-status)) err-already-init)
        (asserts! (> price u0) err-invalid-price)
        (asserts! (not (is-eq seller buyer)) err-same-parties)
        
        (var-set property-seller seller)
        (var-set property-buyer (some buyer))
        (var-set sale-price price)
        (var-set escrow-amount (/ (* price u10) u100))
        (var-set init-status true)
        (ok true)))

;; Make deposit payment
(define-public (deposit-payment)
    (let
        ((deposit (var-get escrow-amount)))
        (begin
            (asserts! (var-get init-status) err-not-init)
            (asserts! (is-buyer) err-owner-only)
            (asserts! (not (var-get payment-status)) err-already-paid)
            
            (try! (stx-transfer? deposit tx-sender (as-contract tx-sender)))
            (var-set payment-status true)
            (map-set escrow-ledger u1
                {
                    tx-amount: deposit,
                    block: block-height,
                    action: "DEPOSIT"
                })
            (ok true))))

;; Make final payment
(define-public (complete-payment)
    (let
        ((final-amount (- (var-get sale-price) (var-get escrow-amount))))
        (begin
            (asserts! (var-get init-status) err-not-init)
            (asserts! (is-buyer) err-owner-only)
            (asserts! (var-get payment-status) err-not-paid)
            
            (try! (stx-transfer? final-amount tx-sender (var-get property-seller)))
            (var-set completion-status true)
            (map-set escrow-ledger u2
                {
                    tx-amount: final-amount,
                    block: block-height,
                    action: "COMPLETE"
                })
            (ok true))))

;; Return deposit to buyer
(define-public (return-deposit)
    (let
        ((buyer-addr (unwrap! (var-get property-buyer) err-not-init)))
        (begin
            (asserts! (var-get init-status) err-not-init)
            (asserts! (is-owner) err-owner-only)
            (asserts! (var-get payment-status) err-not-paid)
            (asserts! (not (var-get completion-status)) err-invalid-state)
            
            (try! (as-contract (stx-transfer? (var-get escrow-amount) tx-sender buyer-addr)))
            (var-set payment-status false)
            (map-set escrow-ledger u3
                {
                    tx-amount: (var-get escrow-amount),
                    block: block-height,
                    action: "REFUND"
                })
            (ok true))))

;; Read contract status
(define-read-only (get-status)
    {
        seller: (var-get property-seller),
        buyer: (var-get property-buyer),
        price: (var-get sale-price),
        deposit: (var-get escrow-amount),
        initialized: (var-get init-status),
        paid: (var-get payment-status),
        completed: (var-get completion-status)
    })

;; Read transaction details
(define-read-only (get-tx-details (tx-id uint))
    (map-get? escrow-ledger tx-id))
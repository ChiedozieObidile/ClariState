;; SecureEstate: A Secure Escrow Smart Contract for Real Estate Transactions
;; Version: 2.1
;; Author: Your Organization
;; License: MIT

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-DAYS-ACTIVE u365)
(define-constant MIN-YEAR u1900)
(define-constant MAX-YEAR u2100)
(define-constant BLOCKS-PER-DAY u144)
(define-constant DEPOSIT-PERCENTAGE u10)
(define-constant MAX-UINT u340282366920938463463374607431768211455)

;; Error Constants
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
(define-constant ERR-DEADLINE-PASSED (err u110))
(define-constant ERR-INSPECTION-FAILED (err u111))
(define-constant ERR-INVALID-AMOUNT (err u112))
(define-constant ERR-INVALID-DAYS (err u113))
(define-constant ERR-INVALID-PROPERTY-ID (err u114))
(define-constant ERR-INVALID-SIZE (err u115))
(define-constant ERR-INVALID-YEAR (err u116))
(define-constant ERR-INVALID-ADDRESS (err u117))
(define-constant ERR-OVERFLOW (err u118))

;; Data Variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var seller principal CONTRACT-OWNER)
(define-data-var buyer (optional principal) none)
(define-data-var property-price uint u0)
(define-data-var deposit-amount uint u0)
(define-data-var is-initialized bool false)
(define-data-var is-paid bool false)
(define-data-var is-completed bool false)
(define-data-var deadline uint u0)
(define-data-var inspection-passed bool false)
(define-data-var maintenance-fund uint u0)

;; Data Maps
(define-map allowed-principals principal bool)
(define-map transaction-details
  { tx-id: uint }
  {
    amount: uint,
    timestamp: uint,
    status: (string-ascii 20)
  })

(define-map property-details
  { property-id: uint }
  {
    address: (string-ascii 50),
    size: uint,
    year-built: uint,
    inspection-date: uint
  })

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner)))

(define-private (is-seller)
  (is-eq tx-sender (var-get seller)))

(define-private (is-buyer)
  (match (var-get buyer)
    buyer-principal (is-eq tx-sender buyer-principal)
    false))

(define-private (check-principal (principal-to-check principal))
  (begin
    (asserts! (not (is-eq principal-to-check CONTRACT-OWNER)) ERR-INVALID-PRINCIPAL)
    (asserts! (not (is-eq principal-to-check tx-sender)) ERR-INVALID-PRINCIPAL)
    (ok principal-to-check)))

(define-private (validate-and-store-principal (principal-to-store principal))
  (begin
    (try! (check-principal principal-to-store))
    (map-set allowed-principals principal-to-store true)
    (ok principal-to-store)))

(define-private (check-deadline)
  (if (> block-height (var-get deadline))
    ERR-DEADLINE-PASSED
    (ok true)))

(define-private (validate-days-active (days uint))
  (if (and (> days u0) (<= days MAX-DAYS-ACTIVE))
    (ok days)
    ERR-INVALID-DAYS))

(define-private (validate-property-id (id uint))
  (if (and (> id u0) (< id MAX-UINT))
    (ok id)
    ERR-INVALID-PROPERTY-ID))

(define-private (validate-property-size (size uint))
  (if (and (> size u0) (< size MAX-UINT))
    (ok size)
    ERR-INVALID-SIZE))

(define-private (validate-year (year uint))
  (if (and (>= year MIN-YEAR) (<= year MAX-YEAR))
    (ok year)
    ERR-INVALID-YEAR))

(define-private (validate-address (addr (string-ascii 50)))
  (if (> (len addr) u0)
    (ok addr)
    ERR-INVALID-ADDRESS))

(define-private (validate-inspection-status (status bool))
  (ok status))

(define-private (calculate-blocks-from-days (days uint))
  (let ((validated-days (try! (validate-days-active days))))
    (asserts! (< (* validated-days BLOCKS-PER-DAY) MAX-UINT) ERR-OVERFLOW)
    (ok (* validated-days BLOCKS-PER-DAY))))

(define-private (safe-add (a uint) (b uint))
  (let ((sum (+ a b)))
    (asserts! (>= sum a) ERR-OVERFLOW)
    (ok sum)))

;; Public Functions
(define-public (initialize-escrow (new-seller principal) (new-buyer principal) (price uint) (days uint))
  (begin
    (asserts! (not (var-get is-initialized)) ERR-ALREADY-INITIALIZED)
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (> price u0) ERR-WRONG-PRICE)
    (asserts! (not (is-eq new-seller new-buyer)) ERR-INVALID-PRINCIPAL)
    
    (let ((validated-days (unwrap! (validate-days-active days) ERR-INVALID-DAYS))
          (blocks (try! (calculate-blocks-from-days validated-days))))
      
      (try! (validate-and-store-principal new-seller))
      (try! (validate-and-store-principal new-buyer))
      
      (var-set seller new-seller)
      (var-set buyer (some new-buyer))
      (var-set property-price price)
      (var-set deposit-amount (/ (* price DEPOSIT-PERCENTAGE) u100))
      (try! (safe-add block-height blocks))
      (var-set deadline (+ block-height blocks))
      (var-set is-initialized true)
      (ok true))))

(define-public (register-property (id uint) (addr (string-ascii 50)) (size uint) (year uint))
  (begin
    (asserts! (is-seller) ERR-NOT-AUTHORIZED)
    (asserts! (var-get is-initialized) ERR-NOT-INITIALIZED)
    
    (let ((validated-id (unwrap! (validate-property-id id) ERR-INVALID-PROPERTY-ID))
          (validated-addr (unwrap! (validate-address addr) ERR-INVALID-ADDRESS))
          (validated-size (unwrap! (validate-property-size size) ERR-INVALID-SIZE))
          (validated-year (unwrap! (validate-year year) ERR-INVALID-YEAR)))
      
      (map-set property-details
        { property-id: validated-id }
        {
          address: validated-addr,
          size: validated-size,
          year-built: validated-year,
          inspection-date: u0
        })
      (ok true))))

(define-public (record-inspection (id uint) (status bool))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (var-get is-initialized) ERR-NOT-INITIALIZED)
    
    (let ((validated-id (unwrap! (validate-property-id id) ERR-INVALID-PROPERTY-ID))
          (validated-status (unwrap! (validate-inspection-status status) ERR-INVALID-STATE)))
      (var-set inspection-passed validated-status)
      (ok true))))

(define-public (pay-deposit)
  (let ((deposit (var-get deposit-amount)))
    (begin
      (try! (check-deadline))
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
        })
      (ok true))))

(define-public (pay-remaining)
  (let ((remaining (- (var-get property-price) (var-get deposit-amount))))
    (begin
      (try! (check-deadline))
      (asserts! (var-get is-initialized) ERR-NOT-INITIALIZED)
      (asserts! (is-buyer) ERR-NOT-AUTHORIZED)
      (asserts! (var-get is-paid) ERR-NOT-PAID)
      (asserts! (var-get inspection-passed) ERR-INSPECTION-FAILED)
      
      (try! (stx-transfer? remaining tx-sender (var-get seller)))
      (var-set is-completed true)
      (map-set transaction-details {tx-id: u2}
        {
          amount: remaining,
          timestamp: block-height,
          status: "COMPLETED"
        })
      (ok true))))

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
        })
      (ok true))))

(define-public (add-maintenance-fund (amount uint))
  (begin
    (asserts! (var-get is-completed) ERR-INVALID-STATE)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set maintenance-fund (+ (var-get maintenance-fund) amount))
    (ok true)))

;; Read-only Functions
(define-read-only (get-escrow-details)
  {
    seller: (var-get seller),
    buyer: (var-get buyer),
    price: (var-get property-price),
    deposit: (var-get deposit-amount),
    is-initialized: (var-get is-initialized),
    is-paid: (var-get is-paid),
    is-completed: (var-get is-completed),
    deadline: (var-get deadline),
    inspection-status: (var-get inspection-passed),
    maintenance-balance: (var-get maintenance-fund)
  })

(define-read-only (get-transaction-detail (tx-id uint))
  (map-get? transaction-details {tx-id: tx-id}))

(define-read-only (get-property-detail (property-id uint))
  (map-get? property-details {property-id: property-id}))

(define-read-only (is-allowed-principal (principal-to-check principal))
  (default-to false (map-get? allowed-principals principal-to-check)))

(define-read-only (get-time-remaining)
  (if (> (var-get deadline) block-height)
    (some (- (var-get deadline) block-height))
    none))
;; Lending Contract - P2P lending on Stacks
;; Built with @stacks/transactions

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_LOAN_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_FUNDED (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))

;; Data vars
(define-data-var loan-count uint u0)
(define-data-var total-borrowed uint u0)
(define-data-var total-repaid uint u0)

;; Maps
(define-map loans uint {
  borrower: principal,
  lender: (optional principal),
  amount: uint,
  interest-rate: uint,
  duration: uint,
  status: (string-ascii 20),
  created-at: uint
})

;; Read-only functions
(define-read-only (get-loan-count)
  (var-get loan-count))

(define-read-only (get-total-borrowed)
  (var-get total-borrowed))

(define-read-only (get-loan (id uint))
  (map-get? loans id))

(define-read-only (calculate-repayment (id uint))
  (match (map-get? loans id)
    loan
    (let (
      (principal-amount (get amount loan))
      (interest (/ (* principal-amount (get interest-rate loan)) u100))
    )
      (+ principal-amount interest))
    u0))

;; Public functions
(define-public (request-loan (amount uint) (interest-rate uint) (duration uint))
  (let ((new-id (+ (var-get loan-count) u1)))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (map-set loans new-id {
      borrower: tx-sender,
      lender: none,
      amount: amount,
      interest-rate: interest-rate,
      duration: duration,
      status: "pending",
      created-at: block-height
    })
    (var-set loan-count new-id)
    (ok new-id)))

(define-public (fund-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
    (asserts! (is-eq (get status loan) "pending") ERR_ALREADY_FUNDED)
    (try! (stx-transfer? (get amount loan) tx-sender (get borrower loan)))
    (map-set loans loan-id (merge loan {
      lender: (some tx-sender),
      status: "active"
    }))
    (var-set total-borrowed (+ (var-get total-borrowed) (get amount loan)))
    (ok true)))

(define-public (repay-loan (loan-id uint))
  (let (
    (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
    (repayment (calculate-repayment loan-id))
    (lender (unwrap! (get lender loan) ERR_NOT_AUTHORIZED))
  )
    (asserts! (is-eq tx-sender (get borrower loan)) ERR_NOT_AUTHORIZED)
    (try! (stx-transfer? repayment tx-sender lender))
    (map-set loans loan-id (merge loan { status: "repaid" }))
    (var-set total-repaid (+ (var-get total-repaid) repayment))
    (ok repayment)))

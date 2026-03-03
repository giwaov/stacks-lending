;; Lending Contract - P2P lending on Stacks
;; Built with @stacks/transactions

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_LOAN_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_FUNDED (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_LOAN_NOT_ACTIVE (err u104))
(define-constant ERR_NOT_OVERDUE (err u105))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u106))
(define-constant ERR_ALREADY_LIQUIDATED (err u107))
(define-constant COLLATERAL_RATIO u150) ;; 150% collateralization required
(define-constant LATE_FEE_RATE u5) ;; 5% late fee

;; Data vars
(define-data-var loan-count uint u0)
(define-data-var total-borrowed uint u0)
(define-data-var total-repaid uint u0)
(define-data-var total-liquidated uint u0)
(define-data-var platform-fee-rate uint u1) ;; 1% platform fee

;; Maps
(define-map loans uint {
  borrower: principal,
  lender: (optional principal),
  amount: uint,
  interest-rate: uint,
  duration: uint,
  status: (string-ascii 20),
  created-at: uint,
  collateral: uint,
  due-block: uint
})

;; Credit scores based on repayment history
(define-map credit-scores principal {
  loans-taken: uint,
  loans-repaid: uint,
  loans-defaulted: uint,
  total-borrowed: uint,
  total-repaid: uint
})

;; Read-only functions
(define-read-only (get-loan-count)
  (var-get loan-count))

(define-read-only (get-total-borrowed)
  (var-get total-borrowed))

(define-read-only (get-total-repaid)
  (var-get total-repaid))

(define-read-only (get-total-liquidated)
  (var-get total-liquidated))

(define-read-only (get-loan (id uint))
  (map-get? loans id))

(define-read-only (get-credit-score (user principal))
  (default-to {
    loans-taken: u0,
    loans-repaid: u0,
    loans-defaulted: u0,
    total-borrowed: u0,
    total-repaid: u0
  } (map-get? credit-scores user)))

(define-read-only (calculate-credit-rating (user principal))
  (let (
    (score (get-credit-score user))
    (taken (get loans-taken score))
    (repaid (get loans-repaid score))
  )
    (if (is-eq taken u0)
      u50 ;; Default score for new users
      (/ (* repaid u100) taken)))) ;; Percentage of loans repaid

(define-read-only (calculate-repayment (id uint))
  (match (map-get? loans id)
    loan
    (let (
      (principal-amount (get amount loan))
      (interest (/ (* principal-amount (get interest-rate loan)) u100))
    )
      (+ principal-amount interest))
    u0))

(define-read-only (calculate-required-collateral (amount uint))
  (/ (* amount COLLATERAL_RATIO) u100))

(define-read-only (is-loan-overdue (id uint))
  (match (map-get? loans id)
    loan
    (and (is-eq (get status loan) "active")
         (> block-height (get due-block loan)))
    false))

(define-read-only (calculate-late-fee (id uint))
  (match (map-get? loans id)
    loan
    (if (is-loan-overdue id)
      (/ (* (get amount loan) LATE_FEE_RATE) u100)
      u0)
    u0))

(define-read-only (get-total-due (id uint))
  (+ (calculate-repayment id) (calculate-late-fee id)))

;; Public functions
(define-public (request-loan (amount uint) (interest-rate uint) (duration uint))
  (let (
    (new-id (+ (var-get loan-count) u1))
    (required-collateral (calculate-required-collateral amount))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    ;; Transfer collateral to contract
    (try! (stx-transfer? required-collateral tx-sender (as-contract tx-sender)))
    (map-set loans new-id {
      borrower: tx-sender,
      lender: none,
      amount: amount,
      interest-rate: interest-rate,
      duration: duration,
      status: "pending",
      created-at: block-height,
      collateral: required-collateral,
      due-block: u0
    })
    (var-set loan-count new-id)
    ;; Update credit score
    (let ((score (get-credit-score tx-sender)))
      (map-set credit-scores tx-sender (merge score {
        loans-taken: (+ (get loans-taken score) u1),
        total-borrowed: (+ (get total-borrowed score) amount)
      })))
    (ok new-id)))

(define-public (cancel-loan-request (loan-id uint))
  (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get borrower loan)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status loan) "pending") ERR_LOAN_NOT_ACTIVE)
    ;; Return collateral
    (try! (as-contract (stx-transfer? (get collateral loan) tx-sender (get borrower loan))))
    (map-set loans loan-id (merge loan { status: "cancelled" }))
    (ok true)))

(define-public (fund-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
    (asserts! (is-eq (get status loan) "pending") ERR_ALREADY_FUNDED)
    (try! (stx-transfer? (get amount loan) tx-sender (get borrower loan)))
    (map-set loans loan-id (merge loan {
      lender: (some tx-sender),
      status: "active",
      due-block: (+ block-height (get duration loan))
    }))
    (var-set total-borrowed (+ (var-get total-borrowed) (get amount loan)))
    (ok true)))

(define-public (repay-loan (loan-id uint))
  (let (
    (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
    (total-due (get-total-due loan-id))
    (lender (unwrap! (get lender loan) ERR_NOT_AUTHORIZED))
  )
    (asserts! (is-eq tx-sender (get borrower loan)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status loan) "active") ERR_LOAN_NOT_ACTIVE)
    ;; Pay lender
    (try! (stx-transfer? total-due tx-sender lender))
    ;; Return collateral to borrower
    (try! (as-contract (stx-transfer? (get collateral loan) tx-sender (get borrower loan))))
    (map-set loans loan-id (merge loan { status: "repaid" }))
    (var-set total-repaid (+ (var-get total-repaid) total-due))
    ;; Update credit score - successful repayment
    (let ((score (get-credit-score (get borrower loan))))
      (map-set credit-scores (get borrower loan) (merge score {
        loans-repaid: (+ (get loans-repaid score) u1),
        total-repaid: (+ (get total-repaid score) total-due)
      })))
    (ok total-due)))

(define-public (liquidate-loan (loan-id uint))
  (let (
    (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
    (lender (unwrap! (get lender loan) ERR_NOT_AUTHORIZED))
  )
    (asserts! (is-eq (get status loan) "active") ERR_LOAN_NOT_ACTIVE)
    (asserts! (is-loan-overdue loan-id) ERR_NOT_OVERDUE)
    ;; Transfer collateral to lender
    (try! (as-contract (stx-transfer? (get collateral loan) tx-sender lender)))
    (map-set loans loan-id (merge loan { status: "liquidated" }))
    (var-set total-liquidated (+ (var-get total-liquidated) (get collateral loan)))
    ;; Update credit score - default
    (let ((score (get-credit-score (get borrower loan))))
      (map-set credit-scores (get borrower loan) (merge score {
        loans-defaulted: (+ (get loans-defaulted score) u1)
      })))
    (ok true)))

;; Admin functions
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set platform-fee-rate new-fee)
    (ok true)))

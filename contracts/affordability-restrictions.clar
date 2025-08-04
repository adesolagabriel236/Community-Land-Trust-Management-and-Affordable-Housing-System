;; Housing Affordability Restriction Contract
;; Limits resale prices to maintain affordability for future residents

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-UNIT-NOT-FOUND (err u201))
(define-constant ERR-UNIT-EXISTS (err u202))
(define-constant ERR-INVALID-PRICE (err u203))
(define-constant ERR-PRICE-EXCEEDS-LIMIT (err u204))
(define-constant ERR-INVALID-APPRECIATION-RATE (err u205))

;; Data Variables
(define-data-var next-unit-id uint u1)
(define-data-var default-appreciation-rate uint u300) ;; 3% annual appreciation
(define-data-var ami-percentage uint u8000) ;; 80% of Area Median Income

;; Data Maps
(define-map housing-units
  { unit-id: uint }
  {
    parcel-id: uint,
    unit-address: (string-ascii 200),
    initial-price: uint,
    current-max-price: uint,
    last-sale-price: uint,
    last-sale-date: uint,
    appreciation-rate: uint,
    affordability-period: uint,
    created-at: uint
  }
)

(define-map price-history
  { unit-id: uint, sale-sequence: uint }
  {
    sale-price: uint,
    sale-date: uint,
    buyer: principal,
    seller: principal
  }
)

(define-map ami-data
  { year: uint }
  {
    median-income: uint,
    updated-at: uint,
    updated-by: principal
  }
)

(define-map affordability-administrators
  { admin: principal }
  { authorized: bool, added-at: uint }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-admin)
  (or
    (is-contract-owner)
    (default-to false (get authorized (map-get? affordability-administrators { admin: tx-sender })))
  )
)

;; Administrative Functions
(define-public (add-affordability-administrator (admin principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set affordability-administrators
      { admin: admin }
      { authorized: true, added-at: block-height }
    ))
  )
)

(define-public (set-default-appreciation-rate (rate uint))
  (begin
    (asserts! (is-authorized-admin) ERR-NOT-AUTHORIZED)
    (asserts! (<= rate u500) ERR-INVALID-APPRECIATION-RATE) ;; Max 5% annual
    (var-set default-appreciation-rate rate)
    (ok true)
  )
)

(define-public (set-ami-percentage (percentage uint))
  (begin
    (asserts! (is-authorized-admin) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= percentage u3000) (<= percentage u12000)) ERR-INVALID-PRICE) ;; 30-120% AMI
    (var-set ami-percentage percentage)
    (ok true)
  )
)

(define-public (update-ami-data (year uint) (median-income uint))
  (begin
    (asserts! (is-authorized-admin) ERR-NOT-AUTHORIZED)
    (asserts! (> median-income u0) ERR-INVALID-PRICE)
    (map-set ami-data
      { year: year }
      {
        median-income: median-income,
        updated-at: block-height,
        updated-by: tx-sender
      }
    )
    (ok true)
  )
)

;; Housing Unit Management
(define-public (register-housing-unit
  (parcel-id uint)
  (unit-address (string-ascii 200))
  (initial-price uint)
  (affordability-period uint)
)
  (let
    (
      (unit-id (var-get next-unit-id))
    )
    (asserts! (is-authorized-admin) ERR-NOT-AUTHORIZED)
    (asserts! (> initial-price u0) ERR-INVALID-PRICE)
    (asserts! (is-none (map-get? housing-units { unit-id: unit-id })) ERR-UNIT-EXISTS)

    (map-set housing-units
      { unit-id: unit-id }
      {
        parcel-id: parcel-id,
        unit-address: unit-address,
        initial-price: initial-price,
        current-max-price: initial-price,
        last-sale-price: initial-price,
        last-sale-date: block-height,
        appreciation-rate: (var-get default-appreciation-rate),
        affordability-period: affordability-period,
        created-at: block-height
      }
    )

    (var-set next-unit-id (+ unit-id u1))
    (ok unit-id)
  )
)

(define-public (record-sale
  (unit-id uint)
  (sale-price uint)
  (buyer principal)
  (seller principal)
)
  (let
    (
      (unit-data (unwrap! (map-get? housing-units { unit-id: unit-id }) ERR-UNIT-NOT-FOUND))
      (max-allowed-price (calculate-max-price unit-id))
    )
    (asserts! (is-authorized-admin) ERR-NOT-AUTHORIZED)
    (asserts! (<= sale-price max-allowed-price) ERR-PRICE-EXCEEDS-LIMIT)

    ;; Record sale in history
    (map-set price-history
      { unit-id: unit-id, sale-sequence: block-height }
      {
        sale-price: sale-price,
        sale-date: block-height,
        buyer: buyer,
        seller: seller
      }
    )

    ;; Update unit data
    (map-set housing-units
      { unit-id: unit-id }
      (merge unit-data {
        last-sale-price: sale-price,
        last-sale-date: block-height,
        current-max-price: max-allowed-price
      })
    )

    (ok true)
  )
)

;; Price Calculation Functions
(define-private (calculate-max-price (unit-id uint))
  (match (map-get? housing-units { unit-id: unit-id })
    unit-data
    (let
      (
        (years-elapsed (/ (- block-height (get last-sale-date unit-data)) u52560)) ;; Approx blocks per year
        (appreciation-factor (+ u10000 (* (get appreciation-rate unit-data) years-elapsed)))
        (appreciated-price (/ (* (get last-sale-price unit-data) appreciation-factor) u10000))
      )
      appreciated-price
    )
    u0
  )
)

(define-read-only (get-max-allowable-price (unit-id uint))
  (calculate-max-price unit-id)
)

(define-read-only (calculate-ami-based-price (year uint))
  (match (map-get? ami-data { year: year })
    ami-info
    (let
      (
        (median-income (get median-income ami-info))
        (target-percentage (var-get ami-percentage))
        (annual-housing-budget (/ (* median-income target-percentage) u10000))
        (max-affordable-price (* annual-housing-budget u5)) ;; 5x annual housing budget
      )
      max-affordable-price
    )
    u0
  )
)

(define-public (validate-sale-price (unit-id uint) (proposed-price uint))
  (let
    (
      (max-price (calculate-max-price unit-id))
    )
    (ok (<= proposed-price max-price))
  )
)

;; Read-only Functions
(define-read-only (get-unit-info (unit-id uint))
  (map-get? housing-units { unit-id: unit-id })
)

(define-read-only (get-price-history (unit-id uint) (sale-sequence uint))
  (map-get? price-history { unit-id: unit-id, sale-sequence: sale-sequence })
)

(define-read-only (get-current-ami-data (year uint))
  (map-get? ami-data { year: year })
)

(define-read-only (get-affordability-settings)
  {
    default-appreciation-rate: (var-get default-appreciation-rate),
    ami-percentage: (var-get ami-percentage)
  }
)

(define-read-only (is-price-compliant (unit-id uint) (proposed-price uint))
  (<= proposed-price (calculate-max-price unit-id))
)

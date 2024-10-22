;; Decentralized Delivery Network Smart Contract

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-rating (err u103))
(define-constant err-invalid-status (err u104))
(define-constant err-invalid-cancellation (err u105))
(define-constant err-unauthorized (err u106))
(define-constant err-invalid-dispute (err u107))

;; Define additional maps
(define-map disputes
  { package-id: uint }
  {
    complainant: principal,
    reason: (string-ascii 100),
    status: (string-ascii 20),
    timestamp: uint
  }
)

(define-map courier-stats
  { courier-id: principal }
  {
    completed-deliveries: uint,
    cancelled-deliveries: uint,
    disputed-deliveries: uint,
    total-earnings: uint
  }
)

(define-map package-history
  { package-id: uint }
  {
    status-updates: (list 10 {
      status: (string-ascii 20),
      timestamp: uint,
      updated-by: principal
    })
  }
)

;; Define data maps
(define-map packages 
  { package-id: uint }
  { 
    sender: principal,
    recipient: principal,
    courier: (optional principal),
    status: (string-ascii 20),
    price: uint,
    pickup-location: (string-ascii 50),
    delivery-location: (string-ascii 50)
  }
)

(define-map couriers
  { courier-id: principal }
  { 
    name: (string-ascii 50),
    rating: uint,
    total-deliveries: uint
  }
)

;; Define non-fungible token for packages
(define-non-fungible-token package-nft uint)

;; Get package details
(define-read-only (get-package-details (package-id uint))
  (map-get? packages { package-id: package-id })
)

;; Get courier details
(define-read-only (get-courier-details (courier-id principal))
  (map-get? couriers { courier-id: courier-id })
)


;; Create a new package
(define-public (create-package (package-id uint) (recipient principal) (price uint) (pickup-location (string-ascii 50)) (delivery-location (string-ascii 50)))
  (let
    (
      (package-data {
        sender: tx-sender,
        recipient: recipient,
        courier: none,
        status: "created",
        price: price,
        pickup-location: pickup-location,
        delivery-location: delivery-location
      })
    )
    (asserts! (is-none (map-get? packages { package-id: package-id })) err-already-exists)
    (try! (nft-mint? package-nft package-id tx-sender))
    (ok (map-set packages { package-id: package-id } package-data))
  )
)

;; Register as a courier
(define-public (register-courier (name (string-ascii 50)))
  (let
    (
      (courier-data {
        name: name,
        rating: u0,
        total-deliveries: u0
      })
    )
    (asserts! (is-none (map-get? couriers { courier-id: tx-sender })) err-already-exists)
    (ok (map-set couriers { courier-id: tx-sender } courier-data))
  )
)

;; Accept a package for delivery
(define-public (accept-package (package-id uint))
  (let
    (
      (package-data (unwrap! (map-get? packages { package-id: package-id }) err-not-found))
    )
    (asserts! (is-some (map-get? couriers { courier-id: tx-sender })) err-not-found)
    (asserts! (is-none (get courier package-data)) err-already-exists)
    (ok (map-set packages { package-id: package-id }
      (merge package-data { 
        courier: (some tx-sender),
        status: "in-transit"
      })
    ))
  )
)

;; Complete a delivery
(define-public (complete-delivery (package-id uint))
  (let
    (
      (package-data (unwrap! (map-get? packages { package-id: package-id }) err-not-found))
      (courier (unwrap! (get courier package-data) err-not-found))
    )
    (asserts! (is-eq tx-sender courier) err-owner-only)
    (try! (stx-transfer? (get price package-data) (get sender package-data) courier))
    (map-set packages { package-id: package-id }
      (merge package-data { 
        status: "delivered"
      })
    )
    (let
      (
        (courier-data (unwrap! (map-get? couriers { courier-id: courier }) err-not-found))
      )
      (ok (map-set couriers { courier-id: courier }
        (merge courier-data {
          total-deliveries: (+ (get total-deliveries courier-data) u1)
        })
      ))
    )
  )
)

;; Rate a courier
(define-public (rate-courier (courier principal) (rating uint))
  (let
    (
      (courier-data (unwrap! (map-get? couriers { courier-id: courier }) err-not-found))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    (ok (map-set couriers { courier-id: courier }
      (merge courier-data {
        rating: (/ (+ (* (get rating courier-data) (get total-deliveries courier-data)) rating)
                   (+ (get total-deliveries courier-data) u1))
      })
    ))
  )
)

;; Cancel a package delivery
(define-public (cancel-package (package-id uint))
  (let
    (
      (package-data (unwrap! (map-get? packages { package-id: package-id }) err-not-found))
    )
    (asserts! (or 
      (is-eq tx-sender (get sender package-data))
      (is-eq tx-sender (get recipient package-data))
    ) err-unauthorized)
    (asserts! (is-eq (get status package-data) "created") err-invalid-cancellation)
    (try! (nft-burn? package-nft package-id (get sender package-data)))
    (ok (map-set packages { package-id: package-id }
      (merge package-data { 
        status: "cancelled"
      })
    ))
  )
)

;; Update package location
(define-public (update-package-location (package-id uint) (location (string-ascii 50)))
  (let
    (
      (package-data (unwrap! (map-get? packages { package-id: package-id }) err-not-found))
      (courier (unwrap! (get courier package-data) err-not-found))
    )
    (asserts! (is-eq tx-sender courier) err-unauthorized)
    (asserts! (is-eq (get status package-data) "in-transit") err-invalid-status)
    (ok (map-set package-history { package-id: package-id }
      {
        status-updates: (unwrap-panic (as-max-len? 
          (append (default-to (list ) (get status-updates (map-get? package-history { package-id: package-id })))
          {
            status: "location-updated",
            timestamp: block-height,
            updated-by: tx-sender
          }
        ) u10))
      }
    ))
  )
)

;; File a dispute
(define-public (file-dispute (package-id uint) (reason (string-ascii 100)))
  (let
    (
      (package-data (unwrap! (map-get? packages { package-id: package-id }) err-not-found))
    )
    (asserts! (or 
      (is-eq tx-sender (get sender package-data))
      (is-eq tx-sender (get recipient package-data))
    ) err-unauthorized)
    (asserts! (is-none (map-get? disputes { package-id: package-id })) err-already-exists)
    (ok (map-set disputes { package-id: package-id }
      {
        complainant: tx-sender,
        reason: reason,
        status: "open",
        timestamp: block-height
      }
    ))
  )
)

;; Get courier statistics
(define-read-only (get-courier-stats (courier-id principal))
  (map-get? courier-stats { courier-id: courier-id })
)

;; Get package history
(define-read-only (get-package-history (package-id uint))
  (map-get? package-history { package-id: package-id })
)

;; Get dispute details
(define-read-only (get-dispute-details (package-id uint))
  (map-get? disputes { package-id: package-id })
)

;; Update courier stats after delivery
(define-public (update-courier-stats (courier-id principal) (earnings uint))
  (let
    (
      (stats (default-to {
        completed-deliveries: u0,
        cancelled-deliveries: u0,
        disputed-deliveries: u0,
        total-earnings: u0
      } (map-get? courier-stats { courier-id: courier-id })))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set courier-stats { courier-id: courier-id }
      (merge stats {
        completed-deliveries: (+ (get completed-deliveries stats) u1),
        total-earnings: (+ (get total-earnings stats) earnings)
      })
    ))
  )
)


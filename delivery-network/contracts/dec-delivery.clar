;; Decentralized Delivery Network Smart Contract

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-rating (err u103))

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

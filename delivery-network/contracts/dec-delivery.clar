;; Decentralized Delivery Network Smart Contract

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))

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
(define-non-fungible-token package uint)
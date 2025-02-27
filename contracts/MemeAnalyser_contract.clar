;; MemeAnalyzer: A DeFi platform for analyzing and tracking memecoin metrics
;; Author: Claude
;; Version: 1.0

(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-TOKEN-ALREADY-REGISTERED (err u102))
(define-constant ERR-INVALID-TOKEN (err u103))
(define-constant ERR-NO-LIQUIDITY-PAIR (err u104))
(define-constant ERR-TOKEN-NOT-REGISTERED (err u105))
(define-constant ERR-ALREADY-SUBSCRIBED (err u106))
(define-constant ERR-INSUFFICIENT-FEE (err u107))
(define-constant ERR-ALREADY-ANALYZER (err u108))
(define-constant ERR-INSUFFICIENT-STAKE (err u109))
(define-constant ERR-NOT-ANALYZER (err u110))

;; Alert Types
(define-constant ALERT-PRICE-SPIKE u1)
(define-constant ALERT-LIQUIDITY-REMOVAL u2)
(define-constant ALERT-WHALE-TRANSACTION u3)
(define-constant ALERT-SUSPICIOUS-ACTIVITY u4)

;; Data structures

;; MemeToken struct
(define-map meme-tokens 
  { token-address: principal }
  {
    name: (string-ascii 32),
    symbol: (string-ascii 8),
    creation-timestamp: uint,
    initial-liquidity: uint,
    pair-address: principal,
    is-verified: bool,
    social-score: uint,
    technical-score: uint,
    liquidity-score: uint,
    holder-score: uint
  }
)

;; TokenMetrics struct
(define-map token-metrics
  { token-address: principal }
  {
    price: uint,
    market-cap: uint,
    liquidity-amount: uint,
    volume-24h: uint,
    holder-count: uint,
    last-updated: uint
  }
)

;; Alert struct
(define-map token-alerts
  { token-address: principal, alert-id: uint }
  {
    alert-type: uint,
    timestamp: uint,
    description: (string-ascii 256),
    is-active: bool
  }
)

;; Tracking alert counts per token
(define-map alert-counts
  { token-address: principal }
  { count: uint }
)

;; Registered Tokens
(define-data-var registered-tokens-count uint u0)
(define-map registered-tokens
  { index: uint }
  { token-address: principal }
)

;; User Subscriptions
(define-map user-subscriptions
  { user: principal, token-address: principal }
  { subscribed: bool }
)

;; Analyzers
(define-map analyzers
  { address: principal }
  { is-active: bool }
)

;; Contract Owner
(define-data-var contract-owner principal tx-sender)

;; Contract Settings
(define-data-var subscription-fee uint u10000000) ;; 10 STX
(define-data-var analyzer-stake uint u100000000) ;; 100 STX
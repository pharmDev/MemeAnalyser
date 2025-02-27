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
;; Events
(define-trait token-event-trait
  (
    (token-registered (principal (string-ascii 32) (string-ascii 8)) (response bool uint))
    (token-verified (principal bool) (response bool uint))
    (metrics-updated (principal uint uint) (response bool uint))
    (alert-triggered (principal uint (string-ascii 256)) (response bool uint))
    (subscription-added (principal principal) (response bool uint))
    (analyzer-added (principal) (response bool uint))
    (analyzer-removed (principal) (response bool uint))
  )
)

;; Helpers

;; Check if caller is the contract owner
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Check if caller is an analyzer
(define-private (is-analyzer)
  (default-to 
    false
    (get is-active (map-get? analyzers { address: tx-sender }))
  )
)

;; Check if token exists
(define-private (token-exists (token-address principal))
  (is-some (map-get? meme-tokens { token-address: token-address }))
)

;; Get token alert count
(define-private (get-alert-count (token-address principal))
  (default-to 
    u0
    (get count (map-get? alert-counts { token-address: token-address }))
  )
)

;; Increment token alert count
(define-private (increment-alert-count (token-address principal))
  (let ((current-count (get-alert-count token-address)))
    (map-set alert-counts
      { token-address: token-address }
      { count: (+ u1 current-count) }
    )
    (+ u1 current-count)
  )
)

;; Public Functions

;; Register a new token for analysis
(define-public (register-token (token-address principal) (name (string-ascii 32)) (symbol (string-ascii 8)) (pair-address principal) (initial-liquidity uint))
  (begin
    ;; Check token not already registered
    (asserts! (not (token-exists token-address)) ERR-TOKEN-ALREADY-REGISTERED)
    
    ;; In a real implementation, we would check for a valid pair and liquidity
    ;; For this example, we just require them as parameters
    
    ;; Add token to registry
    (map-set meme-tokens
      { token-address: token-address }
      {
        name: name,
        symbol: symbol,
        creation-timestamp: block-height,
        initial-liquidity: initial-liquidity,
        pair-address: pair-address,
        is-verified: false,
        social-score: u0,
        technical-score: u0,
        liquidity-score: u0,
        holder-score: u0
      }
    )
    
    ;; Add to registered tokens list
    (let ((current-count (var-get registered-tokens-count)))
      (map-set registered-tokens
        { index: current-count }
        { token-address: token-address }
      )
      (var-set registered-tokens-count (+ u1 current-count))
    )
    
    ;; Initialize alert count
    (map-set alert-counts
      { token-address: token-address }
      { count: u0 }
    )
    
    ;; Emit event
    (print { event: "token-registered", token: token-address, name: name, symbol: symbol })
    (ok true)
  )
)
;; Update metrics for a token
(define-public (update-metrics 
  (token-address principal)
  (price uint)
  (market-cap uint)
  (liquidity-amount uint)
  (volume-24h uint)
  (holder-count uint)
)
  (begin
    ;; Check caller is authorized
    (asserts! (is-analyzer) ERR-NOT-AUTHORIZED)
    
    ;; Check token exists
    (asserts! (token-exists token-address) ERR-TOKEN-NOT-REGISTERED)
    
    ;; Update metrics
    (map-set token-metrics
      { token-address: token-address }
      {
        price: price,
        market-cap: market-cap,
        liquidity-amount: liquidity-amount,
        volume-24h: volume-24h,
        holder-count: holder-count,
        last-updated: block-height
      }
    )
    
    ;; Detect anomalies
    (detect-anomalies token-address liquidity-amount)
    
    ;; Emit event
    (print { event: "metrics-updated", token: token-address, price: price, market-cap: market-cap })
    (ok true)
  )
)

;; Set verification status
(define-public (set-verification-status (token-address principal) (is-verified bool))
  (begin
    ;; Check caller is owner
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    
    ;; Check token exists
    (asserts! (token-exists token-address) ERR-TOKEN-NOT-REGISTERED)
    
    ;; Update verification status
    (match (map-get? meme-tokens { token-address: token-address })
      token-data 
      (map-set meme-tokens
        { token-address: token-address }
        (merge token-data { is-verified: is-verified })
      )
      ERR-TOKEN-NOT-REGISTERED
    )
    
    ;; Emit event
    (print { event: "token-verified", token: token-address, status: is-verified })
    (ok true)
  )
)

;; Update token scores
(define-public (update-scores
  (token-address principal)
  (social-score uint)
  (technical-score uint)
  (liquidity-score uint)
  (holder-score uint)
)
  (begin
    ;; Check caller is authorized
    (asserts! (is-analyzer) ERR-NOT-AUTHORIZED)
    
    ;; Check token exists
    (asserts! (token-exists token-address) ERR-TOKEN-NOT-REGISTERED)
    
    ;; Update scores
    (match (map-get? meme-tokens { token-address: token-address })
      token-data 
      (map-set meme-tokens
        { token-address: token-address }
        (merge token-data 
          { 
            social-score: social-score,
            technical-score: technical-score,
            liquidity-score: liquidity-score,
            holder-score: holder-score
          }
        )
      )
      ERR-TOKEN-NOT-REGISTERED
    )
    
    (ok true)
  )
)

;; Create an alert for a token
(define-public (create-alert
  (token-address principal)
  (alert-type uint)
  (description (string-ascii 256))
)
  (begin
    ;; Check caller is authorized
    (asserts! (is-analyzer) ERR-NOT-AUTHORIZED)
    
    ;; Check token exists
    (asserts! (token-exists token-address) ERR-TOKEN-NOT-REGISTERED)
    
    ;; Add alert to map
    (let ((alert-id (increment-alert-count token-address)))
      (map-set token-alerts
        { token-address: token-address, alert-id: alert-id }
        {
          alert-type: alert-type,
          timestamp: block-height,
          description: description,
          is-active: true
        }
      )
      
      ;; Emit event
      (print { event: "alert-triggered", token: token-address, alert-type: alert-type, description: description })
      (ok alert-id)
    )
  )
)

;; Subscribe to alerts for a token
(define-public (subscribe (token-address principal))
  (begin
    ;; Check token exists
    (asserts! (token-exists token-address) ERR-TOKEN-NOT-REGISTERED)
    
    ;; Check not already subscribed
    (asserts! 
      (not (default-to 
        false 
        (get subscribed (map-get? user-subscriptions { user: tx-sender, token-address: token-address }))
      ))
      ERR-ALREADY-SUBSCRIBED
    )
    
    ;; Check fee paid
    (asserts! (>= (stx-get-balance tx-sender) (var-get subscription-fee)) ERR-INSUFFICIENT-FEE)
    
    ;; Transfer fee
    (unwrap! (stx-transfer? (var-get subscription-fee) tx-sender (as-contract tx-sender)) ERR-INSUFFICIENT-FEE)
    
    ;; Add subscription
    (map-set user-subscriptions
      { user: tx-sender, token-address: token-address }
      { subscribed: true }
    )
    
    ;; Emit event
    (print { event: "subscription-added", user: tx-sender, token: token-address })
    (ok true)
  )
)

;; Private functions

;; Detect anomalies in token metrics
(define-private (detect-anomalies (token-address principal) (current-liquidity uint))
  (begin
    ;; Get token data
    (match (map-get? meme-tokens { token-address: token-address })
      token-data
      (let ((initial-liquidity (get initial-liquidity token-data)))
        ;; Check for significant liquidity reduction
        (if (< (* current-liquidity u100) (* initial-liquidity u70))
          (create-alert token-address ALERT-LIQUIDITY-REMOVAL "Significant liquidity reduction detected")
          (ok u0) ;; No alert
        )
      )
      (ok u0) ;; Token not found, should never happen here
    )
  )
)
;; Register as a token analyzer
(define-public (register-as-analyzer)
  (begin
    ;; Check not already analyzer
    (asserts! 
      (not (default-to 
        false 
        (get is-active (map-get? analyzers { address: tx-sender }))
      ))
      ERR-ALREADY-ANALYZER
    )
    
    ;; Check stake paid
    (asserts! (>= (stx-get-balance tx-sender) (var-get analyzer-stake)) ERR-INSUFFICIENT-STAKE)
    
    ;; Transfer stake
    (unwrap! (stx-transfer? (var-get analyzer-stake) tx-sender (as-contract tx-sender)) ERR-INSUFFICIENT-STAKE)
    
    ;; Add as analyzer
    (map-set analyzers
      { address: tx-sender }
      { is-active: true }
    )
    
    ;; Emit event
    (print { event: "analyzer-added", analyzer: tx-sender })
    (ok true)
  )
)

;; Remove an analyzer
(define-public (remove-analyzer (analyzer principal))
  (begin
    ;; Check caller is owner
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    
    ;; Check is analyzer
    (asserts! 
      (default-to 
        false 
        (get is-active (map-get? analyzers { address: analyzer }))
      )
      ERR-NOT-ANALYZER
    )
    
    ;; Remove analyzer
    (map-set analyzers
      { address: analyzer }
      { is-active: false }
    )
    
    ;; Return stake (would need to track stakes per analyzer in production)
    (unwrap! (as-contract (stx-transfer? (var-get analyzer-stake) tx-sender analyzer)) ERR-NOT-AUTHORIZED)
    
    ;; Emit event
    (print { event: "analyzer-removed", analyzer: analyzer })
    (ok true)
  )
)

;; Set subscription fee
(define-public (set-subscription-fee (new-fee uint))
  (begin
    ;; Check caller is owner
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    
    ;; Update fee
    (var-set subscription-fee new-fee)
    (ok true)
  )
)

;; Set analyzer stake
(define-public (set-analyzer-stake (new-stake uint))
  (begin
    ;; Check caller is owner
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    
    ;; Update stake
    (var-set analyzer-stake new-stake)
    (ok true)
  )
)

;; Withdraw fees
(define-public (withdraw-fees)
  (begin
    ;; Check caller is owner
    (asserts! (is-owner) ERR-NOT-AUTHORIZED)
    
    ;; Get contract balance
    (let ((balance (stx-get-balance (as-contract tx-sender))))
      ;; Transfer all STX to owner
      (unwrap! (as-contract (stx-transfer? balance tx-sender (var-get contract-owner))) ERR-NOT-AUTHORIZED)
      (ok balance)
    )
  )
)

;; Read-only functions

;; Get token data and metrics
(define-read-only (get-token-analysis (token-address principal))
  (begin
    (asserts! (token-exists token-address) ERR-TOKEN-NOT-REGISTERED)
    
    (let (
      (token (map-get? meme-tokens { token-address: token-address }))
      (metrics (map-get? token-metrics { token-address: token-address }))
    )
      {
        token: token,
        metrics: metrics
      }
    )
  )
)

;; Get alert count for a token
(define-read-only (get-token-alert-count (token-address principal))
  (begin
    (asserts! (token-exists token-address) ERR-TOKEN-NOT-REGISTERED)
    (get-alert-count token-address)
  )
)

;; Get a specific alert for a token
(define-read-only (get-token-alert (token-address principal) (alert-id uint))
  (begin
    (asserts! (token-exists token-address) ERR-TOKEN-NOT-REGISTERED)
    (map-get? token-alerts { token-address: token-address, alert-id: alert-id })
  )
)

;; Get total number of registered tokens
(define-read-only (get-registered-token-count)
  (var-get registered-tokens-count)
)

;; Get token address by index
(define-read-only (get-token-by-index (index uint))
  (map-get? registered-tokens { index: index })
)

;; Check if user is subscribed to a token
(define-read-only (is-subscribed (user principal) (token-address principal))
  (default-to 
    false
    (get subscribed (map-get? user-subscriptions { user: user, token-address: token-address }))
  )
)

;; Check if address is an analyzer
(define-read-only (is-active-analyzer (address principal))
  (default-to 
    false
    (get is-active (map-get? analyzers { address: address }))
  )
)
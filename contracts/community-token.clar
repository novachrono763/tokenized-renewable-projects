;; Title: Community Token
;; Description: SIP-010 compliant fungible token for renewable energy project ownership
;; Version: 1.0.0
;; Author: Community Renewable Projects

;; Description: 
;; This contract implements a fungible token standard for representing ownership
;; shares in community renewable energy projects with governance capabilities

;; Define SIP-010 trait locally for compatibility
(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Implement SIP-010 fungible token trait  
;; (impl-trait .community-token.sip-010-trait)

;; Token definitions
(define-fungible-token community-renewable-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-token-owner (err u201))
(define-constant err-insufficient-balance (err u202))
(define-constant err-invalid-amount (err u203))
(define-constant err-transfer-failed (err u204))
(define-constant err-mint-failed (err u205))
(define-constant err-burn-failed (err u206))
(define-constant err-unauthorized (err u207))
(define-constant err-proposal-not-found (err u208))
(define-constant err-proposal-expired (err u209))
(define-constant err-already-voted (err u210))
(define-constant err-voting-period-ended (err u211))
(define-constant err-proposal-not-active (err u212))

;; Token metadata
(define-constant token-name "Community Renewable Token")
(define-constant token-symbol "CRT")
(define-constant token-decimals u6)

;; Governance constants
(define-constant voting-period u144) ;; ~24 hours in blocks
(define-constant quorum-threshold u20) ;; 20% of total supply needed for quorum
(define-constant approval-threshold u50) ;; 50% approval needed

;; Data Variables
(define-data-var token-uri (string-utf8 256) u"https://community-renewable.io/token-metadata.json")
(define-data-var contract-paused bool false)
(define-data-var next-proposal-id uint u1)
(define-data-var total-supply uint u0)

;; Data Maps
(define-map token-balances principal uint)
(define-map allowances { owner: principal, spender: principal } uint)

;; Project token mapping
(define-map project-tokens
  { project-id: uint }
  {
    total-tokens: uint,
    tokens-distributed: uint,
    project-creator: principal,
    created-at: uint
  }
)

;; Investment to token mapping
(define-map investment-tokens
  { project-id: uint, investor: principal }
  {
    tokens-owned: uint,
    investment-amount: uint,
    claimed: bool,
    distribution-date: (optional uint)
  }
)

;; Governance proposals
(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 50),
    description: (string-ascii 200),
    proposer: principal,
    created-at: uint,
    voting-end: uint,
    yes-votes: uint,
    no-votes: uint,
    executed: bool,
    proposal-type: uint
  }
)

;; Voting records
(define-map votes
  { proposal-id: uint, voter: principal }
  {
    vote: bool,
    voting-power: uint,
    timestamp: uint
  }
)

;; Revenue distribution records
(define-map revenue-distributions
  { project-id: uint, distribution-id: uint }
  {
    total-revenue: uint,
    revenue-per-token: uint,
    distribution-date: uint,
    distributed-by: principal
  }
)

;; Claimed revenue tracking
(define-map revenue-claims
  { project-id: uint, distribution-id: uint, claimer: principal }
  {
    amount-claimed: uint,
    claim-date: uint
  }
)

;; Read-only functions
(define-read-only (get-name)
  (ok token-name)
)

(define-read-only (get-symbol)
  (ok token-symbol)
)

(define-read-only (get-decimals)
  (ok token-decimals)
)

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (map-get? token-balances who)))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
  (ok (some (var-get token-uri)))
)

(define-read-only (get-allowance (owner principal) (spender principal))
  (ok (default-to u0 (map-get? allowances { owner: owner, spender: spender })))
)

(define-read-only (get-project-tokens (project-id uint))
  (map-get? project-tokens { project-id: project-id })
)

(define-read-only (get-investment-tokens (project-id uint) (investor principal))
  (map-get? investment-tokens { project-id: project-id, investor: investor })
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-revenue-distribution (project-id uint) (distribution-id uint))
  (map-get? revenue-distributions { project-id: project-id, distribution-id: distribution-id })
)

(define-read-only (get-revenue-claim (project-id uint) (distribution-id uint) (claimer principal))
  (map-get? revenue-claims { project-id: project-id, distribution-id: distribution-id, claimer: claimer })
)

(define-read-only (is-contract-owner (user principal))
  (is-eq user contract-owner)
)

;; Private functions
(define-private (set-balance (who principal) (amount uint))
  (map-set token-balances who amount)
)

(define-private (get-balance-or-default (who principal))
  (default-to u0 (map-get? token-balances who))
)

(define-private (calculate-tokens-for-investment (investment-amount uint) (total-project-funding uint) (total-project-tokens uint))
  (if (> total-project-funding u0)
    (/ (* investment-amount total-project-tokens) total-project-funding)
    u0
  )
)

(define-private (calculate-revenue-share (tokens-owned uint) (total-project-tokens uint) (total-revenue uint))
  (if (> total-project-tokens u0)
    (/ (* tokens-owned total-revenue) total-project-tokens)
    u0
  )
)

;; SIP-010 compliant transfer function
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (let
    (
      (from-balance (get-balance-or-default from))
    )
    (asserts! (not (var-get contract-paused)) err-transfer-failed)
    (asserts! (is-eq from tx-sender) err-not-token-owner)
    (asserts! (>= from-balance amount) err-insufficient-balance)
    (asserts! (> amount u0) err-invalid-amount)
    
    (set-balance from (- from-balance amount))
    (set-balance to (+ (get-balance-or-default to) amount))
    
    (print { 
      action: "transfer",
      from: from,
      to: to,
      amount: amount,
      memo: memo
    })
    
    (ok true)
  )
)

;; Mint tokens for project investment
(define-public (mint-project-tokens 
    (project-id uint)
    (total-tokens uint)
    (project-creator principal)
  )
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (new-total-supply (+ (var-get total-supply) total-tokens))
    )
    (asserts! (not (var-get contract-paused)) err-mint-failed)
    (asserts! (is-contract-owner tx-sender) err-owner-only)
    (asserts! (> total-tokens u0) err-invalid-amount)
    (asserts! (is-none (get-project-tokens project-id)) err-mint-failed)
    
    ;; Create project token record
    (map-set project-tokens
      { project-id: project-id }
      {
        total-tokens: total-tokens,
        tokens-distributed: u0,
        project-creator: project-creator,
        created-at: current-time
      }
    )
    
    ;; Update total supply
    (var-set total-supply new-total-supply)
    
    ;; Mint tokens to contract for distribution
    (try! (ft-mint? community-renewable-token total-tokens (as-contract tx-sender)))
    
    (ok true)
  )
)

;; Distribute tokens to investors
(define-public (distribute-investment-tokens
    (project-id uint)
    (investor principal)
    (investment-amount uint)
    (tokens-amount uint)
  )
  (let
    (
      (project-token-data (unwrap! (get-project-tokens project-id) err-not-token-owner))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (new-distributed (+ (get tokens-distributed project-token-data) tokens-amount))
    )
    (asserts! (not (var-get contract-paused)) err-transfer-failed)
    (asserts! (is-contract-owner tx-sender) err-owner-only)
    (asserts! (> tokens-amount u0) err-invalid-amount)
    (asserts! (<= new-distributed (get total-tokens project-token-data)) err-insufficient-balance)
    
    ;; Record investment token allocation
    (map-set investment-tokens
      { project-id: project-id, investor: investor }
      {
        tokens-owned: tokens-amount,
        investment-amount: investment-amount,
        claimed: false,
        distribution-date: (some current-time)
      }
    )
    
    ;; Update distributed tokens count
    (map-set project-tokens
      { project-id: project-id }
      (merge project-token-data { tokens-distributed: new-distributed })
    )
    
    ;; Transfer tokens from contract to investor
    (try! (as-contract (ft-transfer? community-renewable-token tokens-amount tx-sender investor)))
    
    ;; Update investor balance
    (set-balance investor (+ (get-balance-or-default investor) tokens-amount))
    
    (ok true)
  )
)

;; Claim tokens for investment
(define-public (claim-investment-tokens (project-id uint))
  (let
    (
      (investment-data (unwrap! (get-investment-tokens project-id tx-sender) err-not-token-owner))
      (tokens-amount (get tokens-owned investment-data))
    )
    (asserts! (not (var-get contract-paused)) err-transfer-failed)
    (asserts! (not (get claimed investment-data)) err-transfer-failed)
    (asserts! (> tokens-amount u0) err-invalid-amount)
    
    ;; Mark as claimed
    (map-set investment-tokens
      { project-id: project-id, investor: tx-sender }
      (merge investment-data { claimed: true })
    )
    
    ;; Transfer tokens from contract to investor
    (try! (as-contract (ft-transfer? community-renewable-token tokens-amount tx-sender tx-sender)))
    
    ;; Update investor balance
    (set-balance tx-sender (+ (get-balance-or-default tx-sender) tokens-amount))
    
    (ok true)
  )
)

;; Governance: Create proposal
(define-public (create-proposal
    (title (string-ascii 50))
    (description (string-ascii 200))
    (proposal-type uint)
  )
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (voting-end (+ current-time voting-period))
      (user-balance (get-balance-or-default tx-sender))
    )
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    (asserts! (> user-balance u0) err-insufficient-balance) ;; Must own tokens to propose
    
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposer: tx-sender,
        created-at: current-time,
        voting-end: voting-end,
        yes-votes: u0,
        no-votes: u0,
        executed: false,
        proposal-type: proposal-type
      }
    )
    
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

;; Governance: Vote on proposal
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let
    (
      (proposal-data (unwrap! (get-proposal proposal-id) err-proposal-not-found))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (user-voting-power (get-balance-or-default tx-sender))
      (new-yes-votes (if vote (+ (get yes-votes proposal-data) user-voting-power) (get yes-votes proposal-data)))
      (new-no-votes (if vote (get no-votes proposal-data) (+ (get no-votes proposal-data) user-voting-power)))
    )
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    (asserts! (> user-voting-power u0) err-insufficient-balance)
    (asserts! (<= current-time (get voting-end proposal-data)) err-voting-period-ended)
    (asserts! (is-none (get-vote proposal-id tx-sender)) err-already-voted)
    
    ;; Record vote
    (map-set votes
      { proposal-id: proposal-id, voter: tx-sender }
      {
        vote: vote,
        voting-power: user-voting-power,
        timestamp: current-time
      }
    )
    
    ;; Update proposal vote counts
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal-data {
        yes-votes: new-yes-votes,
        no-votes: new-no-votes
      })
    )
    
    (ok true)
  )
)

;; Revenue distribution
(define-public (distribute-revenue
    (project-id uint)
    (distribution-id uint)
    (total-revenue uint)
  )
  (let
    (
      (project-token-data (unwrap! (get-project-tokens project-id) err-not-token-owner))
      (revenue-per-token (/ total-revenue (get total-tokens project-token-data)))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    (asserts! (is-contract-owner tx-sender) err-owner-only)
    (asserts! (> total-revenue u0) err-invalid-amount)
    (asserts! (> (get total-tokens project-token-data) u0) err-invalid-amount)
    
    (map-set revenue-distributions
      { project-id: project-id, distribution-id: distribution-id }
      {
        total-revenue: total-revenue,
        revenue-per-token: revenue-per-token,
        distribution-date: current-time,
        distributed-by: tx-sender
      }
    )
    
    (ok true)
  )
)

;; Claim revenue share
(define-public (claim-revenue-share
    (project-id uint)
    (distribution-id uint)
  )
  (let
    (
      (distribution-data (unwrap! (get-revenue-distribution project-id distribution-id) err-not-token-owner))
      (investment-data (unwrap! (get-investment-tokens project-id tx-sender) err-not-token-owner))
      (tokens-owned (get tokens-owned investment-data))
      (revenue-share (* tokens-owned (get revenue-per-token distribution-data)))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    (asserts! (> tokens-owned u0) err-insufficient-balance)
    (asserts! (> revenue-share u0) err-invalid-amount)
    (asserts! (is-none (get-revenue-claim project-id distribution-id tx-sender)) err-already-voted)
    
    ;; Record revenue claim
    (map-set revenue-claims
      { project-id: project-id, distribution-id: distribution-id, claimer: tx-sender }
      {
        amount-claimed: revenue-share,
        claim-date: current-time
      }
    )
    
    ;; Transfer STX revenue to claimer
    (try! (as-contract (stx-transfer? revenue-share tx-sender tx-sender)))
    
    (ok revenue-share)
  )
)

;; Admin functions
(define-public (set-token-uri (new-uri (string-utf8 256)))
  (begin
    (asserts! (is-contract-owner tx-sender) err-owner-only)
    (var-set token-uri new-uri)
    (ok true)
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-contract-owner tx-sender) err-owner-only)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (resume-contract)
  (begin
    (asserts! (is-contract-owner tx-sender) err-owner-only)
    (var-set contract-paused false)
    (ok true)
  )
)

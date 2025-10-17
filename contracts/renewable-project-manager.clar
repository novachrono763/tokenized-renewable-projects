;; Title: Renewable Project Manager
;; Description: Smart contract for managing community renewable energy projects
;; Version: 1.0.0
;; Author: Community Renewable Projects

;; Description: 
;; This contract manages the lifecycle of renewable energy projects including
;; registration, funding, milestone tracking, and energy production recording

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-project-not-active (err u105))
(define-constant err-milestone-not-reached (err u106))
(define-constant err-unauthorized (err u107))
(define-constant err-project-completed (err u108))
(define-constant err-invalid-status (err u109))
(define-constant err-credit-not-verified (err u110))
(define-constant err-credit-already-retired (err u111))
(define-constant err-invalid-verification (err u112))

;; Project statuses
(define-constant status-proposed u1)
(define-constant status-funding u2)
(define-constant status-in-progress u3)
(define-constant status-producing u4)
(define-constant status-completed u5)

;; Data Variables
(define-data-var next-project-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var next-credit-id uint u1)

;; Data Maps
(define-map projects
  { project-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    project-type: (string-ascii 20),
    target-funding: uint,
    current-funding: uint,
    creator: principal,
    status: uint,
    created-at: uint,
    completion-date: (optional uint),
    energy-capacity: uint,
    total-energy-produced: uint
  }
)

(define-map project-investments
  { project-id: uint, investor: principal }
  { amount: uint, timestamp: uint }
)

(define-map project-milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-ascii 100),
    funding-percentage: uint,
    completed: bool,
    completion-date: (optional uint)
  }
)

(define-map energy-production
  { project-id: uint, period: uint }
  {
    energy-produced: uint,
    revenue-generated: uint,
    recorded-by: principal,
    timestamp: uint
  }
)

(define-map project-managers
  { project-id: uint }
  { manager: principal, assigned-at: uint }
)

;; Carbon Credit Maps
(define-map carbon-credits
  { credit-id: uint }
  {
    project-id: uint,
    co2-reduced: uint, ;; CO2 in tons * 1000000 (6 decimals)
    verification-date: uint,
    verifier: principal,
    retired: bool,
    retirement-date: (optional uint),
    retired-by: (optional principal),
    baseline-emissions: uint,
    actual-emissions: uint,
    monitoring-period-start: uint,
    monitoring-period-end: uint,
    credit-standard: (string-ascii 20)
  }
)

(define-map project-carbon-totals
  { project-id: uint }
  {
    total-credits-issued: uint,
    total-credits-retired: uint,
    total-co2-reduced: uint,
    last-issuance-date: (optional uint)
  }
)

(define-map credit-ownership
  { credit-id: uint }
  { owner: principal, acquired-date: uint, purchase-price: (optional uint) }
)

(define-map verified-verifiers
  { verifier: principal }
  {
    authorized: bool,
    certification-level: uint,
    authorized-date: uint,
    authorized-by: principal
  }
)

;; Read-only functions
(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

(define-read-only (get-project-investment (project-id uint) (investor principal))
  (map-get? project-investments { project-id: project-id, investor: investor })
)

(define-read-only (get-project-milestone (project-id uint) (milestone-id uint))
  (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-energy-production (project-id uint) (period uint))
  (map-get? energy-production { project-id: project-id, period: period })
)

(define-read-only (get-project-manager (project-id uint))
  (map-get? project-managers { project-id: project-id })
)

(define-read-only (get-contract-info)
  {
    next-project-id: (var-get next-project-id),
    contract-paused: (var-get contract-paused),
    contract-owner: contract-owner
  }
)

(define-read-only (is-contract-owner (user principal))
  (is-eq user contract-owner)
)

(define-read-only (is-project-manager (project-id uint) (user principal))
  (match (map-get? project-managers { project-id: project-id })
    manager-data (is-eq (get manager manager-data) user)
    false
  )
)

;; Carbon Credit read-only functions
(define-read-only (get-carbon-credit (credit-id uint))
  (map-get? carbon-credits { credit-id: credit-id })
)

(define-read-only (get-project-carbon-totals (project-id uint))
  (map-get? project-carbon-totals { project-id: project-id })
)

(define-read-only (get-credit-owner (credit-id uint))
  (map-get? credit-ownership { credit-id: credit-id })
)

(define-read-only (is-verified-verifier (verifier principal))
  (match (map-get? verified-verifiers { verifier: verifier })
    verifier-data (get authorized verifier-data)
    false
  )
)

(define-read-only (get-verifier-info (verifier principal))
  (map-get? verified-verifiers { verifier: verifier })
)

(define-read-only (get-next-credit-id)
  (var-get next-credit-id)
)

;; Private functions
(define-private (validate-project-exists (project-id uint))
  (is-some (map-get? projects { project-id: project-id }))
)

(define-private (validate-funding-amount (amount uint))
  (> amount u0)
)

(define-private (calculate-funding-percentage (current-funding uint) (target-funding uint))
  (if (> target-funding u0)
    (/ (* current-funding u100) target-funding)
    u0
  )
)

;; Carbon Credit private functions
(define-private (validate-co2-amount (co2-amount uint))
  (and (> co2-amount u0) (<= co2-amount u1000000000000)) ;; Max 1 million tons
)

(define-private (validate-monitoring-period (start-date uint) (end-date uint))
  (< start-date end-date)
)

(define-private (calculate-co2-reduction (baseline uint) (actual uint))
  (if (> baseline actual)
    (- baseline actual)
    u0
  )
)

;; Public functions
(define-public (register-project
    (name (string-ascii 50))
    (description (string-ascii 200))
    (project-type (string-ascii 20))
    (target-funding uint)
    (energy-capacity uint)
  )
  (let
    (
      (project-id (var-get next-project-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (> target-funding u0) err-invalid-amount)
    (asserts! (> energy-capacity u0) err-invalid-amount)
    
    (map-set projects
      { project-id: project-id }
      {
        name: name,
        description: description,
        project-type: project-type,
        target-funding: target-funding,
        current-funding: u0,
        creator: tx-sender,
        status: status-proposed,
        created-at: current-time,
        completion-date: none,
        energy-capacity: energy-capacity,
        total-energy-produced: u0
      }
    )
    
    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

(define-public (invest-in-project (project-id uint) (amount uint))
  (let
    (
      (project-data (unwrap! (get-project project-id) err-not-found))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (new-funding (+ (get current-funding project-data) amount))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (validate-funding-amount amount) err-invalid-amount)
    (asserts! (is-eq (get status project-data) status-funding) err-invalid-status)
    
    ;; Record the investment
    (map-set project-investments
      { project-id: project-id, investor: tx-sender }
      { amount: amount, timestamp: current-time }
    )
    
    ;; Update project funding
    (map-set projects
      { project-id: project-id }
      (merge project-data { current-funding: new-funding })
    )
    
    ;; Transfer STX from investor
    (stx-transfer? amount tx-sender (as-contract tx-sender))
  )
)

(define-public (start-funding (project-id uint))
  (let
    (
      (project-data (unwrap! (get-project project-id) err-not-found))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (is-eq tx-sender (get creator project-data)) err-unauthorized)
    (asserts! (is-eq (get status project-data) status-proposed) err-invalid-status)
    
    (map-set projects
      { project-id: project-id }
      (merge project-data { status: status-funding })
    )
    
    (ok true)
  )
)

(define-public (start-project (project-id uint) (manager principal))
  (let
    (
      (project-data (unwrap! (get-project project-id) err-not-found))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (funding-percentage (calculate-funding-percentage 
        (get current-funding project-data) 
        (get target-funding project-data)))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (is-eq tx-sender (get creator project-data)) err-unauthorized)
    (asserts! (is-eq (get status project-data) status-funding) err-invalid-status)
    (asserts! (>= funding-percentage u50) err-insufficient-funds) ;; At least 50% funded
    
    ;; Assign project manager
    (map-set project-managers
      { project-id: project-id }
      { manager: manager, assigned-at: current-time }
    )
    
    ;; Update project status
    (map-set projects
      { project-id: project-id }
      (merge project-data { status: status-in-progress })
    )
    
    (ok true)
  )
)

(define-public (record-energy-production 
    (project-id uint)
    (period uint)
    (energy-produced uint)
    (revenue-generated uint)
  )
  (let
    (
      (project-data (unwrap! (get-project project-id) err-not-found))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (new-total-energy (+ (get total-energy-produced project-data) energy-produced))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (or 
      (is-project-manager project-id tx-sender)
      (is-eq tx-sender (get creator project-data))
    ) err-unauthorized)
    (asserts! (>= (get status project-data) status-producing) err-invalid-status)
    (asserts! (> energy-produced u0) err-invalid-amount)
    
    ;; Record energy production
    (map-set energy-production
      { project-id: project-id, period: period }
      {
        energy-produced: energy-produced,
        revenue-generated: revenue-generated,
        recorded-by: tx-sender,
        timestamp: current-time
      }
    )
    
    ;; Update total energy produced
    (map-set projects
      { project-id: project-id }
      (merge project-data { 
        total-energy-produced: new-total-energy,
        status: status-producing
      })
    )
    
    (ok true)
  )
)

(define-public (complete-milestone (project-id uint) (milestone-id uint))
  (let
    (
      (project-data (unwrap! (get-project project-id) err-not-found))
      (milestone-data (unwrap! (get-project-milestone project-id milestone-id) err-not-found))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (or 
      (is-project-manager project-id tx-sender)
      (is-eq tx-sender (get creator project-data))
    ) err-unauthorized)
    (asserts! (not (get completed milestone-data)) err-milestone-not-reached)
    
    ;; Mark milestone as completed
    (map-set project-milestones
      { project-id: project-id, milestone-id: milestone-id }
      (merge milestone-data { 
        completed: true,
        completion-date: (some current-time)
      })
    )
    
    (ok true)
  )
)

(define-public (complete-project (project-id uint))
  (let
    (
      (project-data (unwrap! (get-project project-id) err-not-found))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (is-eq tx-sender (get creator project-data)) err-unauthorized)
    (asserts! (is-eq (get status project-data) status-producing) err-invalid-status)
    
    ;; Mark project as completed
    (map-set projects
      { project-id: project-id }
      (merge project-data { 
        status: status-completed,
        completion-date: (some current-time)
      })
    )
    
    (ok true)
  )
)

;; Admin functions
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

;; Carbon Credit Management Functions
(define-public (authorize-verifier
    (verifier principal)
    (certification-level uint)
  )
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (is-contract-owner tx-sender) err-owner-only)
    (asserts! (<= certification-level u3) err-invalid-amount) ;; Max level 3
    
    (map-set verified-verifiers
      { verifier: verifier }
      {
        authorized: true,
        certification-level: certification-level,
        authorized-date: current-time,
        authorized-by: tx-sender
      }
    )
    
    (ok true)
  )
)

(define-public (issue-carbon-credit
    (project-id uint)
    (baseline-emissions uint)
    (actual-emissions uint)
    (monitoring-period-start uint)
    (monitoring-period-end uint)
    (credit-standard (string-ascii 20))
  )
  (let
    (
      (project-data (unwrap! (get-project project-id) err-not-found))
      (credit-id (var-get next-credit-id))
      (co2-reduced (calculate-co2-reduction baseline-emissions actual-emissions))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (current-totals (default-to 
        { total-credits-issued: u0, total-credits-retired: u0, total-co2-reduced: u0, last-issuance-date: none }
        (get-project-carbon-totals project-id)
      ))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (is-verified-verifier tx-sender) err-unauthorized)
    (asserts! (>= (get status project-data) status-producing) err-invalid-status)
    (asserts! (validate-co2-amount baseline-emissions) err-invalid-amount)
    (asserts! (validate-co2-amount actual-emissions) err-invalid-amount)
    (asserts! (validate-monitoring-period monitoring-period-start monitoring-period-end) err-invalid-verification)
    (asserts! (> co2-reduced u0) err-invalid-amount)
    
    ;; Create carbon credit
    (map-set carbon-credits
      { credit-id: credit-id }
      {
        project-id: project-id,
        co2-reduced: co2-reduced,
        verification-date: current-time,
        verifier: tx-sender,
        retired: false,
        retirement-date: none,
        retired-by: none,
        baseline-emissions: baseline-emissions,
        actual-emissions: actual-emissions,
        monitoring-period-start: monitoring-period-start,
        monitoring-period-end: monitoring-period-end,
        credit-standard: credit-standard
      }
    )
    
    ;; Set initial ownership to project creator
    (map-set credit-ownership
      { credit-id: credit-id }
      { owner: (get creator project-data), acquired-date: current-time, purchase-price: none }
    )
    
    ;; Update project carbon totals
    (map-set project-carbon-totals
      { project-id: project-id }
      {
        total-credits-issued: (+ (get total-credits-issued current-totals) u1),
        total-credits-retired: (get total-credits-retired current-totals),
        total-co2-reduced: (+ (get total-co2-reduced current-totals) co2-reduced),
        last-issuance-date: (some current-time)
      }
    )
    
    ;; Increment credit ID
    (var-set next-credit-id (+ credit-id u1))
    
    (ok credit-id)
  )
)

(define-public (transfer-carbon-credit
    (credit-id uint)
    (new-owner principal)
    (purchase-price (optional uint))
  )
  (let
    (
      (credit-data (unwrap! (get-carbon-credit credit-id) err-not-found))
      (ownership-data (unwrap! (get-credit-owner credit-id) err-not-found))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (is-eq tx-sender (get owner ownership-data)) err-unauthorized)
    (asserts! (not (get retired credit-data)) err-credit-already-retired)
    
    ;; Transfer ownership
    (map-set credit-ownership
      { credit-id: credit-id }
      {
        owner: new-owner,
        acquired-date: current-time,
        purchase-price: purchase-price
      }
    )
    
    (ok true)
  )
)

(define-public (retire-carbon-credit (credit-id uint))
  (let
    (
      (credit-data (unwrap! (get-carbon-credit credit-id) err-not-found))
      (ownership-data (unwrap! (get-credit-owner credit-id) err-not-found))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (project-id (get project-id credit-data))
      (current-totals (default-to 
        { total-credits-issued: u0, total-credits-retired: u0, total-co2-reduced: u0, last-issuance-date: none }
        (get-project-carbon-totals project-id)
      ))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (is-eq tx-sender (get owner ownership-data)) err-unauthorized)
    (asserts! (not (get retired credit-data)) err-credit-already-retired)
    
    ;; Retire credit
    (map-set carbon-credits
      { credit-id: credit-id }
      (merge credit-data {
        retired: true,
        retirement-date: (some current-time),
        retired-by: (some tx-sender)
      })
    )
    
    ;; Update project totals
    (map-set project-carbon-totals
      { project-id: project-id }
      (merge current-totals {
        total-credits-retired: (+ (get total-credits-retired current-totals) u1)
      })
    )
    
    (ok true)
  )
)

(define-public (add-milestone
    (project-id uint)
    (milestone-id uint)
    (description (string-ascii 100))
    (funding-percentage uint)
  )
  (let
    (
      (project-data (unwrap! (get-project project-id) err-not-found))
    )
    (asserts! (not (var-get contract-paused)) err-project-not-active)
    (asserts! (is-eq tx-sender (get creator project-data)) err-unauthorized)
    (asserts! (is-none (get-project-milestone project-id milestone-id)) err-already-exists)
    (asserts! (<= funding-percentage u100) err-invalid-amount)
    
    (map-set project-milestones
      { project-id: project-id, milestone-id: milestone-id }
      {
        description: description,
        funding-percentage: funding-percentage,
        completed: false,
        completion-date: none
      }
    )
    
    (ok true)
  )
)

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

;; Project statuses
(define-constant status-proposed u1)
(define-constant status-funding u2)
(define-constant status-in-progress u3)
(define-constant status-producing u4)
(define-constant status-completed u5)

;; Data Variables
(define-data-var next-project-id uint u1)
(define-data-var contract-paused bool false)

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

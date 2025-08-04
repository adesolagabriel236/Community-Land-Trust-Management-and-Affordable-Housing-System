;; Resident Participation Governance Contract
;; Enables residents to participate in decision-making about community land trust operations

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u501))
(define-constant ERR-ALREADY-VOTED (err u502))
(define-constant ERR-VOTING-CLOSED (err u503))
(define-constant ERR-INVALID-VOTE (err u504))
(define-constant ERR-QUORUM-NOT-MET (err u505))

;; Proposal Types
(define-constant PROPOSAL-POLICY-CHANGE u1)
(define-constant PROPOSAL-BUDGET-ALLOCATION u2)
(define-constant PROPOSAL-MAINTENANCE-APPROVAL u3)
(define-constant PROPOSAL-MEMBER-REMOVAL u4)
(define-constant PROPOSAL-GENERAL u5)

;; Data Variables
(define-data-var next-proposal-id uint u1)
(define-data-var voting-period uint u10080) ;; ~1 week in blocks
(define-data-var quorum-percentage uint u5000) ;; 50% quorum requirement
(define-data-var total-eligible-voters uint u0)

;; Data Maps
(define-map proposals
  { proposal-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 1000),
    proposal-type: uint,
    proposed-by: principal,
    created-at: uint,
    voting-ends-at: uint,
    yes-votes: uint,
    no-votes: uint,
    abstain-votes: uint,
    status: (string-ascii 20),
    executed: bool,
    execution-data: (optional (string-ascii 500))
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  {
    vote: (string-ascii 10),
    voting-power: uint,
    cast-at: uint,
    reason: (optional (string-ascii 200))
  }
)

(define-map eligible-voters
  { voter: principal }
  {
    voting-power: uint,
    member-since: uint,
    active: bool,
    last-participation: uint
  }
)

(define-map governance-administrators
  { admin: principal }
  { authorized: bool, added-at: uint }
)

(define-map proposal-comments
  { proposal-id: uint, comment-id: uint }
  {
    commenter: principal,
    comment: (string-ascii 500),
    timestamp: uint
  }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-admin)
  (or
    (is-contract-owner)
    (default-to false (get authorized (map-get? governance-administrators { admin: tx-sender })))
  )
)

(define-private (is-eligible-voter)
  (default-to false (get active (map-get? eligible-voters { voter: tx-sender })))
)

;; Administrative Functions
(define-public (add-governance-administrator (admin principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set governance-administrators
      { admin: admin }
      { authorized: true, added-at: block-height }
    ))
  )
)

(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-authorized-admin) ERR-NOT-AUTHORIZED)
    (var-set voting-period new-period)
    (ok true)
  )
)

(define-public (set-quorum-percentage (new-percentage uint))
  (begin
    (asserts! (is-authorized-admin) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-percentage u1000) (<= new-percentage u10000)) ERR-INVALID-VOTE) ;; 10-100%
    (var-set quorum-percentage new-percentage)
    (ok true)
  )
)

;; Voter Management
(define-public (register-eligible-voter (voter principal) (voting-power uint))
  (begin
    (asserts! (is-authorized-admin) ERR-NOT-AUTHORIZED)
    (asserts! (> voting-power u0) ERR-INVALID-VOTE)

    (map-set eligible-voters
      { voter: voter }
      {
        voting-power: voting-power,
        member-since: block-height,
        active: true,
        last-participation: u0
      }
    )

    (var-set total-eligible-voters (+ (var-get total-eligible-voters) u1))
    (ok true)
  )
)

(define-public (update-voter-status (voter principal) (active bool))
  (let
    (
      (voter-data (unwrap! (map-get? eligible-voters { voter: voter }) ERR-NOT-AUTHORIZED))
    )
    (asserts! (is-authorized-admin) ERR-NOT-AUTHORIZED)

    (map-set eligible-voters
      { voter: voter }
      (merge voter-data { active: active })
    )

    (if active
      (var-set total-eligible-voters (+ (var-get total-eligible-voters) u1))
      (var-set total-eligible-voters (- (var-get total-eligible-voters) u1))
    )
    (ok true)
  )
)

;; Proposal Management
(define-public (create-proposal
  (title (string-ascii 200))
  (description (string-ascii 1000))
  (proposal-type uint)
)
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (voting-ends-at (+ block-height (var-get voting-period)))
    )
    (asserts! (is-eligible-voter) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= proposal-type PROPOSAL-POLICY-CHANGE) (<= proposal-type PROPOSAL-GENERAL)) ERR-INVALID-VOTE)

    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposal-type: proposal-type,
        proposed-by: tx-sender,
        created-at: block-height,
        voting-ends-at: voting-ends-at,
        yes-votes: u0,
        no-votes: u0,
        abstain-votes: u0,
        status: "active",
        executed: false,
        execution-data: none
      }
    )

    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (cast-vote
  (proposal-id uint)
  (vote (string-ascii 10))
  (reason (optional (string-ascii 200)))
)
  (let
    (
      (proposal-data (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
      (voter-data (unwrap! (map-get? eligible-voters { voter: tx-sender }) ERR-NOT-AUTHORIZED))
      (voting-power (get voting-power voter-data))
    )
    (asserts! (get active voter-data) ERR-NOT-AUTHORIZED)
    (asserts! (< block-height (get voting-ends-at proposal-data)) ERR-VOTING-CLOSED)
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) ERR-ALREADY-VOTED)
    (asserts! (or (is-eq vote "yes") (is-eq vote "no") (is-eq vote "abstain")) ERR-INVALID-VOTE)

    ;; Record the vote
    (map-set votes
      { proposal-id: proposal-id, voter: tx-sender }
      {
        vote: vote,
        voting-power: voting-power,
        cast-at: block-height,
        reason: reason
      }
    )

    ;; Update proposal vote counts
    (let
      (
        (updated-proposal
          (if (is-eq vote "yes")
            (merge proposal-data { yes-votes: (+ (get yes-votes proposal-data) voting-power) })
            (if (is-eq vote "no")
              (merge proposal-data { no-votes: (+ (get no-votes proposal-data) voting-power) })
              (merge proposal-data { abstain-votes: (+ (get abstain-votes proposal-data) voting-power) })
            )
          )
        )
      )
      (map-set proposals { proposal-id: proposal-id } updated-proposal)
    )

    ;; Update voter participation
    (map-set eligible-voters
      { voter: tx-sender }
      (merge voter-data { last-participation: block-height })
    )

    (ok true)
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let
    (
      (proposal-data (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
      (total-votes (+ (+ (get yes-votes proposal-data) (get no-votes proposal-data)) (get abstain-votes proposal-data)))
      (required-quorum (/ (* (var-get total-eligible-voters) (var-get quorum-percentage)) u10000))
    )
    (asserts! (is-authorized-admin) ERR-NOT-AUTHORIZED)
    (asserts! (>= block-height (get voting-ends-at proposal-data)) ERR-VOTING-CLOSED)
    (asserts! (is-eq (get status proposal-data) "active") ERR-INVALID-VOTE)

    (let
      (
        (quorum-met (>= total-votes required-quorum))
        (proposal-passed (and quorum-met (> (get yes-votes proposal-data) (get no-votes proposal-data))))
        (final-status (if quorum-met (if proposal-passed "passed" "failed") "quorum-not-met"))
      )
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal-data { status: final-status })
      )
      (ok final-status)
    )
  )
)

(define-public (execute-proposal (proposal-id uint) (execution-data (string-ascii 500)))
  (let
    (
      (proposal-data (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
    )
    (asserts! (is-authorized-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status proposal-data) "passed") ERR-INVALID-VOTE)
    (asserts! (not (get executed proposal-data)) ERR-INVALID-VOTE)

    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal-data {
        executed: true,
        execution-data: (some execution-data)
      })
    )
    (ok true)
  )
)

(define-public (add-proposal-comment
  (proposal-id uint)
  (comment (string-ascii 500))
)
  (let
    (
      (proposal-data (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
      (comment-id block-height)
    )
    (asserts! (is-eligible-voter) ERR-NOT-AUTHORIZED)

    (map-set proposal-comments
      { proposal-id: proposal-id, comment-id: comment-id }
      {
        commenter: tx-sender,
        comment: comment,
        timestamp: block-height
      }
    )
    (ok comment-id)
  )
)

;; Read-only Functions
(define-read-only (get-proposal-info (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-vote-info (proposal-id uint) (voter principal))
  (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-voter-info (voter principal))
  (map-get? eligible-voters { voter: voter })
)

(define-read-only (get-proposal-comment (proposal-id uint) (comment-id uint))
  (map-get? proposal-comments { proposal-id: proposal-id, comment-id: comment-id })
)

(define-read-only (get-governance-settings)
  {
    voting-period: (var-get voting-period),
    quorum-percentage: (var-get quorum-percentage),
    total-eligible-voters: (var-get total-eligible-voters)
  }
)

(define-read-only (calculate-quorum-requirement)
  (/ (* (var-get total-eligible-voters) (var-get quorum-percentage)) u10000)
)

(define-read-only (is-proposal-active (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal-data (and
      (is-eq (get status proposal-data) "active")
      (< block-height (get voting-ends-at proposal-data))
    )
    false
  )
)

(define-read-only (get-proposal-results (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal-data (some {
      yes-votes: (get yes-votes proposal-data),
      no-votes: (get no-votes proposal-data),
      abstain-votes: (get abstain-votes proposal-data),
      total-votes: (+ (+ (get yes-votes proposal-data) (get no-votes proposal-data)) (get abstain-votes proposal-data)),
      status: (get status proposal-data)
    })
    none
  )
)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_POLICY_NOT_FOUND (err u101))
(define-constant ERR_BAGGAGE_NOT_FOUND (err u102))
(define-constant ERR_CLAIM_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_POLICY_EXPIRED (err u105))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u106))
(define-constant ERR_INVALID_STATUS (err u107))
(define-constant ERR_CLAIM_TIMEOUT (err u108))
(define-constant ERR_DELAY_NOT_FOUND (err u109))
(define-constant ERR_DELAY_ALREADY_PROCESSED (err u110))
(define-constant ERR_INVALID_DELAY_DURATION (err u111))
(define-constant ERR_NOT_BENEFICIARY (err u112))
(define-constant ERR_TRANSFER_TO_SELF (err u113))
(define-constant ERR_BENEFICIARY_ALREADY_SET (err u114))

(define-data-var policy-id-nonce uint u0)
(define-data-var baggage-id-nonce uint u0)
(define-data-var claim-id-nonce uint u0)
(define-data-var delay-id-nonce uint u0)

(define-map policies 
  { policy-id: uint }
  {
    policyholder: principal,
    coverage-amount: uint,
    premium-paid: uint,
    start-block: uint,
    end-block: uint,
    status: (string-ascii 20),
    vault-balance: uint
  }
)

(define-map baggage-items
  { baggage-id: uint }
  {
    owner: principal,
    policy-id: uint,
    status: (string-ascii 20),
    last-location: (string-ascii 50),
    last-update: uint,
    value: uint
  }
)

(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    baggage-id: uint,
    claimant: principal,
    claim-type: (string-ascii 20),
    amount: uint,
    status: (string-ascii 20),
    submitted-at: uint,
    processed-at: uint,
    evidence: (string-ascii 100)
  }
)

(define-map user-policies
  { user: principal }
  { policy-ids: (list 10 uint) }
)

(define-map policy-baggage
  { policy-id: uint }
  { baggage-ids: (list 5 uint) }
)

(define-map travel-delays
  { delay-id: uint }
  {
    policy-id: uint,
    traveler: principal,
    flight-number: (string-ascii 20),
    scheduled-departure: uint,
    actual-departure: uint,
    delay-duration: uint,
    compensation-amount: uint,
    status: (string-ascii 20),
    reported-at: uint,
    processed-at: uint
  }
)

(define-map policy-beneficiaries
  { policy-id: uint }
  {
    beneficiary: principal,
    emergency-access: bool,
    set-at: uint
  }
)

(define-map transfer-requests
  { policy-id: uint }
  {
    from-user: principal,
    to-user: principal,
    requested-at: uint,
    approved: bool
  }
)

(define-public (create-policy (coverage-amount uint) (duration-blocks uint))
  (let 
    (
      (new-policy-id (+ (var-get policy-id-nonce) u1))
      (premium (/ coverage-amount u20))
      (end-block (+ stacks-block-height duration-blocks))
    )
    (asserts! (>= (stx-get-balance tx-sender) premium) ERR_INSUFFICIENT_FUNDS)
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    (map-set policies
      { policy-id: new-policy-id }
      {
        policyholder: tx-sender,
        coverage-amount: coverage-amount,
        premium-paid: premium,
        start-block: stacks-block-height,
        end-block: end-block,
        status: "active",
        vault-balance: premium
      }
    )
    
    (let ((current-policies (default-to { policy-ids: (list) } (map-get? user-policies { user: tx-sender }))))
      (map-set user-policies
        { user: tx-sender }
        { policy-ids: (unwrap! (as-max-len? (append (get policy-ids current-policies) new-policy-id) u10) ERR_UNAUTHORIZED) }
      )
      true
    )
    
    (var-set policy-id-nonce new-policy-id)
    (ok new-policy-id)
  )
)

(define-public (register-baggage (policy-id uint) (initial-location (string-ascii 50)) (value uint))
  (let 
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (new-baggage-id (+ (var-get baggage-id-nonce) u1))
    )
    (asserts! (is-eq (get policyholder policy) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status policy) "active") ERR_INVALID_STATUS)
    (asserts! (< stacks-block-height (get end-block policy)) ERR_POLICY_EXPIRED)
    
    (map-set baggage-items
      { baggage-id: new-baggage-id }
      {
        owner: tx-sender,
        policy-id: policy-id,
        status: "registered",
        last-location: initial-location,
        last-update: stacks-block-height,
        value: value
      }
    )
    
    (let ((current-baggage (default-to { baggage-ids: (list) } (map-get? policy-baggage { policy-id: policy-id }))))
      (map-set policy-baggage
        { policy-id: policy-id }
        { baggage-ids: (unwrap! (as-max-len? (append (get baggage-ids current-baggage) new-baggage-id) u5) ERR_UNAUTHORIZED) }
      )
      true
    )
    
    (var-set baggage-id-nonce new-baggage-id)
    (ok new-baggage-id)
  )
)

(define-public (update-baggage-status (baggage-id uint) (new-status (string-ascii 20)) (location (string-ascii 50)))
  (let 
    (
      (baggage (unwrap! (map-get? baggage-items { baggage-id: baggage-id }) ERR_BAGGAGE_NOT_FOUND))
    )
    (asserts! (is-eq (get owner baggage) tx-sender) ERR_UNAUTHORIZED)
    
    (map-set baggage-items
      { baggage-id: baggage-id }
      (merge baggage {
        status: new-status,
        last-location: location,
        last-update: stacks-block-height
      })
    )
    (ok true)
  )
)

(define-public (submit-claim (policy-id uint) (baggage-id uint) (claim-type (string-ascii 20)) (amount uint) (evidence (string-ascii 100)))
  (let 
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (baggage (unwrap! (map-get? baggage-items { baggage-id: baggage-id }) ERR_BAGGAGE_NOT_FOUND))
      (new-claim-id (+ (var-get claim-id-nonce) u1))
    )
    (asserts! (is-eq (get policyholder policy) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get owner baggage) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get policy-id baggage) policy-id) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status policy) "active") ERR_INVALID_STATUS)
    (asserts! (< stacks-block-height (get end-block policy)) ERR_POLICY_EXPIRED)
    (asserts! (<= amount (get coverage-amount policy)) ERR_INSUFFICIENT_FUNDS)
    
    (map-set claims
      { claim-id: new-claim-id }
      {
        policy-id: policy-id,
        baggage-id: baggage-id,
        claimant: tx-sender,
        claim-type: claim-type,
        amount: amount,
        status: "pending",
        submitted-at: stacks-block-height,
        processed-at: u0,
        evidence: evidence
      }
    )
    
    (var-set claim-id-nonce new-claim-id)
    (ok new-claim-id)
  )
)

(define-public (process-claim (claim-id uint) (approve bool))
  (let 
    (
      (claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR_CLAIM_NOT_FOUND))
      (policy (unwrap! (map-get? policies { policy-id: (get policy-id claim) }) ERR_POLICY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status claim) "pending") ERR_CLAIM_ALREADY_PROCESSED)
    (asserts! (< (get submitted-at claim) (+ stacks-block-height u144)) ERR_CLAIM_TIMEOUT)
    
    (if approve
      (begin
        (asserts! (>= (get vault-balance policy) (get amount claim)) ERR_INSUFFICIENT_FUNDS)
        (try! (as-contract (stx-transfer? (get amount claim) tx-sender (get claimant claim))))
        
        (map-set policies
          { policy-id: (get policy-id claim) }
          (merge policy {
            vault-balance: (- (get vault-balance policy) (get amount claim))
          })
        )
        
        (map-set claims
          { claim-id: claim-id }
          (merge claim {
            status: "approved",
            processed-at: stacks-block-height
          })
        )
      )
      (map-set claims
        { claim-id: claim-id }
        (merge claim {
          status: "rejected",
          processed-at: stacks-block-height
        })
      )
    )
    (ok approve)
  )
)

(define-public (auto-process-lost-baggage (baggage-id uint))
  (let 
    (
      (baggage (unwrap! (map-get? baggage-items { baggage-id: baggage-id }) ERR_BAGGAGE_NOT_FOUND))
      (policy (unwrap! (map-get? policies { policy-id: (get policy-id baggage) }) ERR_POLICY_NOT_FOUND))
      (time-since-update (- stacks-block-height (get last-update baggage)))
    )
    (asserts! (>= time-since-update u1008) ERR_CLAIM_TIMEOUT)
    (asserts! (is-eq (get status baggage) "lost") ERR_INVALID_STATUS)
    (asserts! (is-eq (get status policy) "active") ERR_INVALID_STATUS)
    
    (let ((payout-amount (if (<= (get value baggage) (get coverage-amount policy))
                            (get value baggage)
                            (get coverage-amount policy))))
      (asserts! (>= (get vault-balance policy) payout-amount) ERR_INSUFFICIENT_FUNDS)
      (try! (as-contract (stx-transfer? payout-amount tx-sender (get owner baggage))))
      
      (map-set policies
        { policy-id: (get policy-id baggage) }
        (merge policy {
          vault-balance: (- (get vault-balance policy) payout-amount)
        })
      )
      
      (ok payout-amount)
    )
  )
)

(define-public (extend-policy (policy-id uint) (additional-blocks uint))
  (let 
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (extension-premium (/ (get coverage-amount policy) u40))
    )
    (asserts! (is-eq (get policyholder policy) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status policy) "active") ERR_INVALID_STATUS)
    (asserts! (>= (stx-get-balance tx-sender) extension-premium) ERR_INSUFFICIENT_FUNDS)
    
    (try! (stx-transfer? extension-premium tx-sender (as-contract tx-sender)))
    
    (map-set policies
      { policy-id: policy-id }
      (merge policy {
        end-block: (+ (get end-block policy) additional-blocks),
        vault-balance: (+ (get vault-balance policy) extension-premium)
      })
    )
    (ok true)
  )
)

(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-baggage (baggage-id uint))
  (map-get? baggage-items { baggage-id: baggage-id })
)

(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-user-policies (user principal))
  (map-get? user-policies { user: user })
)

(define-read-only (get-policy-baggage (policy-id uint))
  (map-get? policy-baggage { policy-id: policy-id })
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (is-policy-active (policy-id uint))
  (match (map-get? policies { policy-id: policy-id })
    policy (and 
      (is-eq (get status policy) "active")
      (< stacks-block-height (get end-block policy))
    )
    false
  )
)

(define-private (calculate-delay-compensation (delay-duration uint) (coverage-amount uint))
  (if (>= delay-duration u360)
    (/ coverage-amount u4)
    (if (>= delay-duration u180)
      (/ coverage-amount u8)
      (if (>= delay-duration u60)
        (/ coverage-amount u16)
        u0
      )
    )
  )
)

(define-public (report-flight-delay (policy-id uint) (flight-number (string-ascii 20)) (scheduled-departure uint) (actual-departure uint))
  (let 
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (new-delay-id (+ (var-get delay-id-nonce) u1))
      (delay-duration (- actual-departure scheduled-departure))
      (compensation (calculate-delay-compensation delay-duration (get coverage-amount policy)))
    )
    (asserts! (is-eq (get policyholder policy) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status policy) "active") ERR_INVALID_STATUS)
    (asserts! (< stacks-block-height (get end-block policy)) ERR_POLICY_EXPIRED)
    (asserts! (> delay-duration u0) ERR_INVALID_DELAY_DURATION)
    (asserts! (>= (get vault-balance policy) compensation) ERR_INSUFFICIENT_FUNDS)
    
    (map-set travel-delays
      { delay-id: new-delay-id }
      {
        policy-id: policy-id,
        traveler: tx-sender,
        flight-number: flight-number,
        scheduled-departure: scheduled-departure,
        actual-departure: actual-departure,
        delay-duration: delay-duration,
        compensation-amount: compensation,
        status: "pending",
        reported-at: stacks-block-height,
        processed-at: u0
      }
    )
    
    (var-set delay-id-nonce new-delay-id)
    (ok new-delay-id)
  )
)

(define-public (process-delay-compensation (delay-id uint))
  (let 
    (
      (delay-record (unwrap! (map-get? travel-delays { delay-id: delay-id }) ERR_DELAY_NOT_FOUND))
      (policy (unwrap! (map-get? policies { policy-id: (get policy-id delay-record) }) ERR_POLICY_NOT_FOUND))
    )
    (asserts! (is-eq (get status delay-record) "pending") ERR_DELAY_ALREADY_PROCESSED)
    (asserts! (>= (get vault-balance policy) (get compensation-amount delay-record)) ERR_INSUFFICIENT_FUNDS)
    (asserts! (>= (get delay-duration delay-record) u60) ERR_INVALID_DELAY_DURATION)
    
    (if (> (get compensation-amount delay-record) u0)
      (begin
        (try! (as-contract (stx-transfer? (get compensation-amount delay-record) tx-sender (get traveler delay-record))))
        
        (map-set policies
          { policy-id: (get policy-id delay-record) }
          (merge policy {
            vault-balance: (- (get vault-balance policy) (get compensation-amount delay-record))
          })
        )
        
        (map-set travel-delays
          { delay-id: delay-id }
          (merge delay-record {
            status: "compensated",
            processed-at: stacks-block-height
          })
        )
        (ok (get compensation-amount delay-record))
      )
      (begin
        (map-set travel-delays
          { delay-id: delay-id }
          (merge delay-record {
            status: "no-compensation",
            processed-at: stacks-block-height
          })
        )
        (ok u0)
      )
    )
  )
)

(define-read-only (get-delay (delay-id uint))
  (map-get? travel-delays { delay-id: delay-id })
)

(define-read-only (get-delay-compensation-estimate (delay-duration uint) (coverage-amount uint))
  (calculate-delay-compensation delay-duration coverage-amount)
)

(define-private (is-authorized-user (policy-id uint) (user principal))
  (match (map-get? policies { policy-id: policy-id })
    policy 
      (if (is-eq (get policyholder policy) user)
        true
        (match (map-get? policy-beneficiaries { policy-id: policy-id })
          beneficiary-data (is-eq (get beneficiary beneficiary-data) user)
          false
        )
      )
    false
  )
)

(define-public (set-policy-beneficiary (policy-id uint) (beneficiary principal) (emergency-access bool))
  (let 
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (existing-beneficiary (map-get? policy-beneficiaries { policy-id: policy-id }))
    )
    (asserts! (is-eq (get policyholder policy) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq beneficiary tx-sender)) ERR_TRANSFER_TO_SELF)
    (asserts! (is-none existing-beneficiary) ERR_BENEFICIARY_ALREADY_SET)
    
    (map-set policy-beneficiaries
      { policy-id: policy-id }
      {
        beneficiary: beneficiary,
        emergency-access: emergency-access,
        set-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (update-beneficiary-access (policy-id uint) (emergency-access bool))
  (let 
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (beneficiary-data (unwrap! (map-get? policy-beneficiaries { policy-id: policy-id }) ERR_NOT_BENEFICIARY))
    )
    (asserts! (is-eq (get policyholder policy) tx-sender) ERR_UNAUTHORIZED)
    
    (map-set policy-beneficiaries
      { policy-id: policy-id }
      (merge beneficiary-data {
        emergency-access: emergency-access
      })
    )
    (ok true)
  )
)

(define-public (request-policy-transfer (policy-id uint) (to-user principal))
  (let 
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
    )
    (asserts! (is-eq (get policyholder policy) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq to-user tx-sender)) ERR_TRANSFER_TO_SELF)
    
    (map-set transfer-requests
      { policy-id: policy-id }
      {
        from-user: tx-sender,
        to-user: to-user,
        requested-at: stacks-block-height,
        approved: false
      }
    )
    (ok true)
  )
)

(define-public (approve-policy-transfer (policy-id uint))
  (let 
    (
      (transfer-request (unwrap! (map-get? transfer-requests { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
    )
    (asserts! (is-eq (get to-user transfer-request) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (get approved transfer-request)) ERR_CLAIM_ALREADY_PROCESSED)
    
    (begin
      (map-set policies
        { policy-id: policy-id }
        (merge policy {
          policyholder: tx-sender
        })
      )
      
      (map-set user-policies
        { user: (get from-user transfer-request) }
        { policy-ids: (list) }
      )
      
      (let ((new-user-policies (default-to { policy-ids: (list) } (map-get? user-policies { user: tx-sender }))))
        (map-set user-policies
          { user: tx-sender }
          { policy-ids: (unwrap! (as-max-len? (append (get policy-ids new-user-policies) policy-id) u10) ERR_UNAUTHORIZED) }
        )
      )
      
      (map-set transfer-requests
        { policy-id: policy-id }
        (merge transfer-request {
          approved: true
        })
      )
      
      (ok true)
    )
  )
)

(define-public (beneficiary-submit-claim (policy-id uint) (baggage-id uint) (claim-type (string-ascii 20)) (amount uint) (evidence (string-ascii 100)))
  (let 
    (
      (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR_POLICY_NOT_FOUND))
      (baggage (unwrap! (map-get? baggage-items { baggage-id: baggage-id }) ERR_BAGGAGE_NOT_FOUND))
      (beneficiary-data (unwrap! (map-get? policy-beneficiaries { policy-id: policy-id }) ERR_NOT_BENEFICIARY))
      (new-claim-id (+ (var-get claim-id-nonce) u1))
    )
    (asserts! (is-eq (get beneficiary beneficiary-data) tx-sender) ERR_NOT_BENEFICIARY)
    (asserts! (get emergency-access beneficiary-data) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get policy-id baggage) policy-id) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status policy) "active") ERR_INVALID_STATUS)
    (asserts! (< stacks-block-height (get end-block policy)) ERR_POLICY_EXPIRED)
    (asserts! (<= amount (get coverage-amount policy)) ERR_INSUFFICIENT_FUNDS)
    
    (map-set claims
      { claim-id: new-claim-id }
      {
        policy-id: policy-id,
        baggage-id: baggage-id,
        claimant: tx-sender,
        claim-type: claim-type,
        amount: amount,
        status: "pending",
        submitted-at: stacks-block-height,
        processed-at: u0,
        evidence: evidence
      }
    )
    
    (var-set claim-id-nonce new-claim-id)
    (ok new-claim-id)
  )
)

(define-read-only (get-policy-beneficiary (policy-id uint))
  (map-get? policy-beneficiaries { policy-id: policy-id })
)

(define-read-only (get-transfer-request (policy-id uint))
  (map-get? transfer-requests { policy-id: policy-id })
)

(define-read-only (can-user-access-policy (policy-id uint) (user principal))
  (is-authorized-user policy-id user)
)
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

(define-data-var policy-id-nonce uint u0)
(define-data-var baggage-id-nonce uint u0)
(define-data-var claim-id-nonce uint u0)

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
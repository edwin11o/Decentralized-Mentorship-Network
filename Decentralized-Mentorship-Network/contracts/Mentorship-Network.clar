;; Decentralized Mentorship Network Smart Contract
;; A platform for connecting mentors and mentees with reputation tracking and payment handling

;; Error constants
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_ALREADY_EXISTS (err u402))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_INSUFFICIENT_BALANCE (err u403))
(define-constant ERR_ALREADY_COMPLETED (err u405))
(define-constant ERR_INVALID_RATING (err u406))
(define-constant ERR_SESSION_NOT_STARTED (err u407))

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Platform fee (2%)
(define-constant PLATFORM_FEE u200) ;; 200 basis points = 2%

;; Data structures
(define-map mentors
  { mentor: principal }
  {
    name: (string-ascii 50),
    expertise: (string-ascii 100),
    hourly-rate: uint,
    rating: uint,
    total-sessions: uint,
    active: bool
  }
)

(define-map mentees
  { mentee: principal }
  {
    name: (string-ascii 50),
    interests: (string-ascii 100),
    active: bool
  }
)

(define-map sessions
  { session-id: uint }
  {
    mentor: principal,
    mentee: principal,
    duration: uint,
    rate: uint,
    total-cost: uint,
    status: (string-ascii 20), ;; "pending", "active", "completed", "cancelled"
    created-at: uint,
    started-at: (optional uint),
    completed-at: (optional uint)
  }
)

(define-map session-ratings
  { session-id: uint }
  {
    mentor-rating: (optional uint), ;; 1-5 stars
    mentee-rating: (optional uint), ;; 1-5 stars
    mentor-feedback: (optional (string-ascii 200)),
    mentee-feedback: (optional (string-ascii 200))
  }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

;; Session ID counter
(define-data-var next-session-id uint u1)

;; Platform revenue
(define-data-var platform-revenue uint u0)

;; Register as mentor
(define-public (register-mentor (name (string-ascii 50)) (expertise (string-ascii 100)) (hourly-rate uint))
  (begin
    (asserts! (> hourly-rate u0) ERR_INVALID_AMOUNT)
    (asserts! (is-none (map-get? mentors { mentor: tx-sender })) ERR_ALREADY_EXISTS)
    (ok (map-set mentors
      { mentor: tx-sender }
      {
        name: name,
        expertise: expertise,
        hourly-rate: hourly-rate,
        rating: u0,
        total-sessions: u0,
        active: true
      }
    ))
  )
)

;; Register as mentee
(define-public (register-mentee (name (string-ascii 50)) (interests (string-ascii 100)))
  (begin
    (asserts! (is-none (map-get? mentees { mentee: tx-sender })) ERR_ALREADY_EXISTS)
    (ok (map-set mentees
      { mentee: tx-sender }
      {
        name: name,
        interests: interests,
        active: true
      }
    ))
  )
)

;; Update mentor profile
(define-public (update-mentor-profile (name (string-ascii 50)) (expertise (string-ascii 100)) (hourly-rate uint))
  (let ((mentor-data (unwrap! (map-get? mentors { mentor: tx-sender }) ERR_NOT_FOUND)))
    (asserts! (> hourly-rate u0) ERR_INVALID_AMOUNT)
    (ok (map-set mentors
      { mentor: tx-sender }
      (merge mentor-data {
        name: name,
        expertise: expertise,
        hourly-rate: hourly-rate
      })
    ))
  )
)

;; Deposit funds to user balance
(define-public (deposit-funds (amount uint))
  (let ((current-balance (default-to u0 (get balance (map-get? user-balances { user: tx-sender })))))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (ok (map-set user-balances
      { user: tx-sender }
      { balance: (+ current-balance amount) }
    ))
  )
)

;; Book a mentorship session
(define-public (book-session (mentor principal) (duration uint))
  (let (
    (mentor-data (unwrap! (map-get? mentors { mentor: mentor }) ERR_NOT_FOUND))
    (session-id (var-get next-session-id))
    (total-cost (* duration (get hourly-rate mentor-data)))
    (mentee-balance (default-to u0 (get balance (map-get? user-balances { user: tx-sender }))))
  )
    (asserts! (> duration u0) ERR_INVALID_AMOUNT)
    (asserts! (get active mentor-data) ERR_NOT_FOUND)
    (asserts! (>= mentee-balance total-cost) ERR_INSUFFICIENT_BALANCE)
    
    ;; Deduct cost from mentee balance
    (map-set user-balances
      { user: tx-sender }
      { balance: (- mentee-balance total-cost) }
    )
    
    ;; Create session
    (map-set sessions
      { session-id: session-id }
      {
        mentor: mentor,
        mentee: tx-sender,
        duration: duration,
        rate: (get hourly-rate mentor-data),
        total-cost: total-cost,
        status: "pending",
        created-at: block-height,
        started-at: none,
        completed-at: none
      }
    )
    
    ;; Initialize ratings
    (map-set session-ratings
      { session-id: session-id }
      {
        mentor-rating: none,
        mentee-rating: none,
        mentor-feedback: none,
        mentee-feedback: none
      }
    )
    
    (var-set next-session-id (+ session-id u1))
    (ok session-id)
  )
)

;; Start a session (mentor only)
(define-public (start-session (session-id uint))
  (let ((session-data (unwrap! (map-get? sessions { session-id: session-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get mentor session-data)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status session-data) "pending") ERR_ALREADY_COMPLETED)
    
    (ok (map-set sessions
      { session-id: session-id }
      (merge session-data {
        status: "active",
        started-at: (some block-height)
      })
    ))
  )
)

;; Complete a session (mentor only)
(define-public (complete-session (session-id uint))
  (let (
    (session-data (unwrap! (map-get? sessions { session-id: session-id }) ERR_NOT_FOUND))
    (mentor (get mentor session-data))
    (total-cost (get total-cost session-data))
    (platform-fee-amount (/ (* total-cost PLATFORM_FEE) u10000))
    (mentor-payment (- total-cost platform-fee-amount))
    (current-mentor-balance (default-to u0 (get balance (map-get? user-balances { user: mentor }))))
  )
    (asserts! (is-eq tx-sender mentor) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status session-data) "active") ERR_SESSION_NOT_STARTED)
    
    ;; Update session status
    (map-set sessions
      { session-id: session-id }
      (merge session-data {
        status: "completed",
        completed-at: (some block-height)
      })
    )
    
    ;; Pay mentor (minus platform fee)
    (map-set user-balances
      { user: mentor }
      { balance: (+ current-mentor-balance mentor-payment) }
    )
    
    ;; Add to platform revenue
    (var-set platform-revenue (+ (var-get platform-revenue) platform-fee-amount))
    
    ;; Update mentor session count
    (let ((mentor-data (unwrap! (map-get? mentors { mentor: mentor }) ERR_NOT_FOUND)))
      (map-set mentors
        { mentor: mentor }
        (merge mentor-data {
          total-sessions: (+ (get total-sessions mentor-data) u1)
        })
      )
    )
    
    (ok true)
  )
)

;; Rate a session
(define-public (rate-session (session-id uint) (rating uint) (feedback (string-ascii 200)))
  (let (
    (session-data (unwrap! (map-get? sessions { session-id: session-id }) ERR_NOT_FOUND))
    (rating-data (unwrap! (map-get? session-ratings { session-id: session-id }) ERR_NOT_FOUND))
    (is-mentor (is-eq tx-sender (get mentor session-data)))
    (is-mentee (is-eq tx-sender (get mentee session-data)))
  )
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (is-eq (get status session-data) "completed") ERR_ALREADY_COMPLETED)
    (asserts! (or is-mentor is-mentee) ERR_NOT_AUTHORIZED)
    
    (if is-mentor
      ;; Mentor rating mentee
      (map-set session-ratings
        { session-id: session-id }
        (merge rating-data {
          mentee-rating: (some rating),
          mentor-feedback: (some feedback)
        })
      )
      ;; Mentee rating mentor
      (begin
        (map-set session-ratings
          { session-id: session-id }
          (merge rating-data {
            mentor-rating: (some rating),
            mentee-feedback: (some feedback)
          })
        )
        ;; Update mentor's average rating
        (update-mentor-rating (get mentor session-data) rating)
      )
    )
    (ok true)
  )
)

;; Update mentor's average rating (private function)
(define-private (update-mentor-rating (mentor principal) (new-rating uint))
  (let ((mentor-data (unwrap-panic (map-get? mentors { mentor: mentor }))))
    (let (
      (current-rating (get rating mentor-data))
      (total-sessions (get total-sessions mentor-data))
      (new-avg-rating (if (is-eq current-rating u0)
        new-rating
        (/ (+ (* current-rating (- total-sessions u1)) new-rating) total-sessions)
      ))
    )
      (map-set mentors
        { mentor: mentor }
        (merge mentor-data { rating: new-avg-rating })
      )
    )
  )
)

;; Withdraw funds
(define-public (withdraw-funds (amount uint))
  (let ((current-balance (default-to u0 (get balance (map-get? user-balances { user: tx-sender })))))
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (map-set user-balances
      { user: tx-sender }
      { balance: (- current-balance amount) }
    )
    
    (as-contract (stx-transfer? amount tx-sender tx-sender))
  )
)

;; Read-only functions

;; Get mentor info
(define-read-only (get-mentor (mentor principal))
  (map-get? mentors { mentor: mentor })
)

;; Get mentee info
(define-read-only (get-mentee (mentee principal))
  (map-get? mentees { mentee: mentee })
)

;; Get session info
(define-read-only (get-session (session-id uint))
  (map-get? sessions { session-id: session-id })
)

;; Get session rating
(define-read-only (get-session-rating (session-id uint))
  (map-get? session-ratings { session-id: session-id })
)

;; Get user balance
(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

;; Get platform revenue (contract owner only)
(define-read-only (get-platform-revenue)
  (var-get platform-revenue)
)
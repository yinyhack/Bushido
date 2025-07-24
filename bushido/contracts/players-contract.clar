;; Samurai Honor Duel - Ancient Way of the Warrior
;; Two samurai commit to hidden fighting stances, then reveal in honorable combat

;; Constants
(define-constant DOJO-MASTER tx-sender)
(define-constant ERR-HONOR-VIOLATED (err u100))
(define-constant ERR-DUEL-NOT-FOUND (err u101))
(define-constant ERR-STANCE-COMMITTED (err u102))
(define-constant ERR-STANCE-NOT-SET (err u103))
(define-constant ERR-ALREADY-SHOWN (err u104))
(define-constant ERR-INVALID-TECHNIQUE (err u105))
(define-constant ERR-DUEL-CONCLUDED (err u106))
(define-constant ERR-TOO-EARLY-REVEAL (err u107))
(define-constant ERR-NOT-PARTICIPANT (err u108))

;; Fighting technique constants
(define-constant KATANA-STRIKE u1)    ;; Defeats Defensive Stance
(define-constant DEFENSIVE-STANCE u2) ;; Defeats Throwing-Star
(define-constant THROWING-STAR u3)    ;; Defeats Katana Strike

;; Duel phases
(define-constant PHASE-PREPARING-STANCE u0)
(define-constant PHASE-REVEALING-TECHNIQUE u1)
(define-constant PHASE-HONOR-DECIDED u2)

;; Data structures
(define-map honor-duels
  { duel-id: uint }
  {
    samurai1: principal,
    samurai2: principal,
    samurai1-hidden-stance: (buff 32),
    samurai2-hidden-stance: (buff 32),
    samurai1-technique: (optional uint),
    samurai2-technique: (optional uint),
    victor-samurai: (optional principal),
    phase: uint,
    duel-commenced: uint,
    honor-stakes: uint,
    location: (string-ascii 20)
  }
)

(define-data-var next-duel-id uint u1)

;; Challenge another samurai to an honor duel
(define-public (challenge-to-duel (opponent-samurai principal) (honor-wager uint) (battlefield (string-ascii 20)))
  (let ((duel-id (var-get next-duel-id)))
    (asserts! (not (is-eq tx-sender opponent-samurai)) ERR-HONOR-VIOLATED)
    (map-set honor-duels
      { duel-id: duel-id }
      {
        samurai1: tx-sender,
        samurai2: opponent-samurai,
        samurai1-hidden-stance: 0x,
        samurai2-hidden-stance: 0x,
        samurai1-technique: none,
        samurai2-technique: none,
        victor-samurai: none,
        phase: PHASE-PREPARING-STANCE,
        duel-commenced: block-height,
        honor-stakes: honor-wager,
        location: battlefield
      }
    )
    (var-set next-duel-id (+ duel-id u1))
    (ok duel-id)
  )
)

;; Set fighting stance in secret (commit phase)
(define-public (set-fighting-stance (duel-id uint) (hidden-stance (buff 32)))
  (let ((duel (unwrap! (map-get? honor-duels { duel-id: duel-id }) ERR-DUEL-NOT-FOUND)))
    (asserts! (is-eq (get phase duel) PHASE-PREPARING-STANCE) ERR-DUEL-CONCLUDED)
    (asserts! (> (len hidden-stance) u0) ERR-INVALID-TECHNIQUE)
    
    (if (is-eq tx-sender (get samurai1 duel))
      (begin
        (asserts! (is-eq (len (get samurai1-hidden-stance duel)) u0) ERR-STANCE-COMMITTED)
        (map-set honor-duels
          { duel-id: duel-id }
          (merge duel { samurai1-hidden-stance: hidden-stance })
        )
        (check-both-stances-set duel-id)
      )
      (if (is-eq tx-sender (get samurai2 duel))
        (begin
          (asserts! (is-eq (len (get samurai2-hidden-stance duel)) u0) ERR-STANCE-COMMITTED)
          (map-set honor-duels
            { duel-id: duel-id }
            (merge duel { samurai2-hidden-stance: hidden-stance })
          )
          (check-both-stances-set duel-id)
        )
        ERR-NOT-PARTICIPANT
      )
    )
  )
)

;; Check if both samurai have set their stances
(define-private (check-both-stances-set (duel-id uint))
  (let ((duel (unwrap! (map-get? honor-duels { duel-id: duel-id }) ERR-DUEL-NOT-FOUND)))
    (if (and 
          (> (len (get samurai1-hidden-stance duel)) u0)
          (> (len (get samurai2-hidden-stance duel)) u0))
      (begin
        (map-set honor-duels
          { duel-id: duel-id }
          (merge duel { phase: PHASE-REVEALING-TECHNIQUE })
        )
        (ok true)
      )
      (ok false)
    )
  )
)

;; Reveal fighting technique with honor
(define-public (reveal-technique (duel-id uint) (technique uint) (spirit-energy uint))
  (let ((duel (unwrap! (map-get? honor-duels { duel-id: duel-id }) ERR-DUEL-NOT-FOUND)))
    (asserts! (is-eq (get phase duel) PHASE-REVEALING-TECHNIQUE) ERR-TOO-EARLY-REVEAL)
    (asserts! (or (is-eq technique KATANA-STRIKE) (is-eq technique DEFENSIVE-STANCE) (is-eq technique THROWING-STAR)) ERR-INVALID-TECHNIQUE)
    
    (let ((technique-hash (sha256 (concat (concat (unwrap-panic (to-consensus-buff? technique)) 
                                                 (unwrap-panic (to-consensus-buff? spirit-energy))) 
                                         (unwrap-panic (to-consensus-buff? tx-sender))))))
      (if (is-eq tx-sender (get samurai1 duel))
        (begin
          (asserts! (is-eq technique-hash (get samurai1-hidden-stance duel)) ERR-INVALID-TECHNIQUE)
          (asserts! (is-none (get samurai1-technique duel)) ERR-ALREADY-SHOWN)
          (map-set honor-duels
            { duel-id: duel-id }
            (merge duel { samurai1-technique: (some technique) })
          )
          (decide-honor-victor duel-id)
        )
        (if (is-eq tx-sender (get samurai2 duel))
          (begin
            (asserts! (is-eq technique-hash (get samurai2-hidden-stance duel)) ERR-INVALID-TECHNIQUE)
            (asserts! (is-none (get samurai2-technique duel)) ERR-ALREADY-SHOWN)
            (map-set honor-duels
              { duel-id: duel-id }
              (merge duel { samurai2-technique: (some technique) })
            )
            (decide-honor-victor duel-id)
          )
          ERR-NOT-PARTICIPANT
        )
      )
    )
  )
)

;; Decide the victor through honorable combat
(define-private (decide-honor-victor (duel-id uint))
  (let ((duel (unwrap! (map-get? honor-duels { duel-id: duel-id }) ERR-DUEL-NOT-FOUND)))
    (match (get samurai1-technique duel)
      technique1
      (match (get samurai2-technique duel)
        technique2
        (let ((victor (resolve-samurai-combat technique1 technique2 (get samurai1 duel) (get samurai2 duel))))
          (map-set honor-duels
            { duel-id: duel-id }
            (merge duel { victor-samurai: victor, phase: PHASE-HONOR-DECIDED })
          )
          (ok victor)
        )
        (ok none)
      )
      (ok none)
    )
  )
)

;; Resolve samurai combat: Katana Strike > Defensive Stance > Throwing Star > Katana Strike
(define-private (resolve-samurai-combat (tech1 uint) (tech2 uint) (samurai1 principal) (samurai2 principal))
  (if (is-eq tech1 tech2)
    none ;; Honorable draw
    (if (or 
          (and (is-eq tech1 KATANA-STRIKE) (is-eq tech2 DEFENSIVE-STANCE))
          (and (is-eq tech1 DEFENSIVE-STANCE) (is-eq tech2 THROWING-STAR))
          (and (is-eq tech1 THROWING-STAR) (is-eq tech2 KATANA-STRIKE)))
      (some samurai1)
      (some samurai2)
    )
  )
)

;; Read-only functions
(define-read-only (get-duel-details (duel-id uint))
  (map-get? honor-duels { duel-id: duel-id })
)

(define-read-only (get-honor-victor (duel-id uint))
  (match (map-get? honor-duels { duel-id: duel-id })
    duel (ok (get victor-samurai duel))
    ERR-DUEL-NOT-FOUND
  )
)

(define-read-only (technique-name (tech-code uint))
  (if (is-eq tech-code KATANA-STRIKE)
    "Katana Strike"
    (if (is-eq tech-code DEFENSIVE-STANCE)
      "Defensive Stance"
      (if (is-eq tech-code THROWING-STAR)
        "Throwing Star"
        "Unknown Technique"
      )
    )
  )
)

(define-read-only (get-battlefield (duel-id uint))
  (match (map-get? honor-duels { duel-id: duel-id })
    duel (ok (get location duel))
    ERR-DUEL-NOT-FOUND
  )
)

(define-read-only (get-honor-stakes (duel-id uint))
  (match (map-get? honor-duels { duel-id: duel-id })
    duel (ok (get honor-stakes duel))
    ERR-DUEL-NOT-FOUND
  )
)

(define-read-only (get-duel-phase (duel-id uint))
  (match (map-get? honor-duels { duel-id: duel-id })
    duel (ok (get phase duel))
    ERR-DUEL-NOT-FOUND
  )
)

;; Check if samurai can participate in the duel
(define-read-only (can-join-duel (duel-id uint) (samurai principal))
  (match (map-get? honor-duels { duel-id: duel-id })
    duel 
    (ok (or (is-eq samurai (get samurai1 duel)) 
            (is-eq samurai (get samurai2 duel))))
    ERR-DUEL-NOT-FOUND
  )
)

;; Calculate duel duration in blocks
(define-read-only (get-duel-duration (duel-id uint))
  (match (map-get? honor-duels { duel-id: duel-id })
    duel (ok (- block-height (get duel-commenced duel)))
    ERR-DUEL-NOT-FOUND
  )
)

;; Get current duel count
(define-read-only (get-total-duels)
  (- (var-get next-duel-id) u1)
)

;; Check if duel is complete
(define-read-only (is-duel-complete (duel-id uint))
  (match (map-get? honor-duels { duel-id: duel-id })
    duel (ok (is-eq (get phase duel) PHASE-HONOR-DECIDED))
    ERR-DUEL-NOT-FOUND
  )
)

;; Get samurai participants
(define-read-only (get-duel-participants (duel-id uint))
  (match (map-get? honor-duels { duel-id: duel-id })
    duel (ok { samurai1: (get samurai1 duel), samurai2: (get samurai2 duel) })
    ERR-DUEL-NOT-FOUND
  )
)

;; Check if both stances are committed
(define-read-only (are-stances-committed (duel-id uint))
  (match (map-get? honor-duels { duel-id: duel-id })
    duel (ok (and 
               (> (len (get samurai1-hidden-stance duel)) u0)
               (> (len (get samurai2-hidden-stance duel)) u0)))
    ERR-DUEL-NOT-FOUND
  )
)

;; Check if both techniques are revealed
(define-read-only (are-techniques-revealed (duel-id uint))
  (match (map-get? honor-duels { duel-id: duel-id })
    duel (ok (and 
               (is-some (get samurai1-technique duel))
               (is-some (get samurai2-technique duel))))
    ERR-DUEL-NOT-FOUND
  )
)

;; Get revealed techniques (only after both are revealed)
(define-read-only (get-revealed-techniques (duel-id uint))
  (match (map-get? honor-duels { duel-id: duel-id })
    duel 
    (if (and (is-some (get samurai1-technique duel)) (is-some (get samurai2-technique duel)))
      (ok { 
        samurai1-technique: (get samurai1-technique duel), 
        samurai2-technique: (get samurai2-technique duel) 
      })
      (err u109)) ;; Techniques not yet revealed
    ERR-DUEL-NOT-FOUND
  )
)

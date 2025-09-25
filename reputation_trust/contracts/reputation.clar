;; title: Reputation & Trust Registry
;; version: 1.0.0
;; summary: On-chain reputation system with staking, badges, and decay mechanisms
;; description: A comprehensive reputation system that tracks user scores, implements stake-based Sybil resistance, and awards transferable NFT badges

;; traits
;;

;; token definitions
(define-non-fungible-token reputation-badge uint)

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-STAKE (err u402))
(define-constant ERR-INVALID-AMOUNT (err u403))
(define-constant ERR-USER-NOT-FOUND (err u404))
(define-constant ERR-BADGE-NOT-FOUND (err u405))
(define-constant ERR-BADGE-EXISTS (err u406))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u407))
(define-constant ERR-TRANSFER-FAILED (err u408))

;; Default values
(define-constant DEFAULT-DECAY-RATE u5) ;; 5% decay per call
(define-constant DEFAULT-MIN-STAKE-AMOUNT u1000000) ;; 1 STX minimum stake (in microSTX)
(define-constant MAX-DECAY-RATE u100) ;; Maximum 100% decay rate
(define-constant MIN-REPUTATION-FOR-BADGE u100) ;; Minimum reputation to mint badges

;; data vars
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var decay-rate uint DEFAULT-DECAY-RATE)
(define-data-var min-stake-amount uint DEFAULT-MIN-STAKE-AMOUNT)
(define-data-var next-badge-id uint u1)
(define-data-var contract-paused bool false)

;; data maps
;; User reputation and staking data: principal -> {score, stake, last-decay-block}
(define-map user-data
    principal
    {
        reputation-score: uint,
        staked-amount: uint,
        last-decay-block: uint,
    }
)

;; Badge metadata: badgeId -> {name, description, creator}
(define-map badge-metadata
    uint
    {
        name: (string-ascii 64),
        description: (string-ascii 256),
        creator: principal,
    }
)

;; User badges: (principal, badgeId) -> true (ownership tracking)
(define-map user-badges
    {
        user: principal,
        badge-id: uint,
    }
    bool
)

;; Authorized contracts that can increment/decrement reputation
(define-map authorized-contracts
    principal
    bool
)

;; public functions

;; Stake STX to participate in the reputation system
(define-public (stake (amount uint))
    (let ((sender tx-sender))
        (asserts! (>= amount (var-get min-stake-amount)) ERR-INVALID-AMOUNT)
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        (match (map-get? user-data sender)
            current-data (map-set user-data sender
                (merge current-data { staked-amount: (+ (get staked-amount current-data) amount) })
            )
            (map-set user-data sender {
                reputation-score: u0,
                staked-amount: amount,
                last-decay-block: stacks-block-height,
            })
        )
        (print {
            event: "StakeAdded",
            user: sender,
            amount: amount,
        })
        (ok true)
    )
)

;; Unstake STX (full amount)
(define-public (unstake)
    (let ((sender tx-sender))
        (match (map-get? user-data sender)
            user-info (let ((staked (get staked-amount user-info)))
                (asserts! (> staked u0) ERR-INSUFFICIENT-STAKE)
                (try! (as-contract (stx-transfer? staked tx-sender sender)))
                (map-set user-data sender (merge user-info { staked-amount: u0 }))
                (print {
                    event: "StakeWithdrawn",
                    user: sender,
                    amount: staked,
                })
                (ok staked)
            )
            ERR-USER-NOT-FOUND
        )
    )
)

;; Partial unstake STX (specify amount)
(define-public (partial-unstake (amount uint))
    (let ((sender tx-sender))
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (match (map-get? user-data sender)
            user-info (let (
                    (staked (get staked-amount user-info))
                    (remaining (if (>= staked amount)
                        (- staked amount)
                        u0
                    ))
                )
                (asserts! (>= staked amount) ERR-INSUFFICIENT-STAKE)
                (asserts! (>= remaining (var-get min-stake-amount))
                    ERR-INSUFFICIENT-STAKE
                )
                (try! (as-contract (stx-transfer? amount tx-sender sender)))
                (map-set user-data sender
                    (merge user-info { staked-amount: remaining })
                )
                (print {
                    event: "PartialStakeWithdrawn",
                    user: sender,
                    amount: amount,
                    remaining: remaining,
                })
                (ok remaining)
            )
            ERR-USER-NOT-FOUND
        )
    )
)

;; read only functions

;; Get user staked amount
(define-read-only (get-stake (user principal))
    (match (map-get? user-data user)
        user-info (ok (get staked-amount user-info))
        ERR-USER-NOT-FOUND
    )
)

;; Get complete user data
(define-read-only (get-user-data (user principal))
    (map-get? user-data user)
)

;; Get current contract settings
(define-read-only (get-contract-settings)
    {
        owner: (var-get contract-owner),
        decay-rate: (var-get decay-rate),
        min-stake: (var-get min-stake-amount),
        next-badge-id: (var-get next-badge-id),
    }
)

;; Get contract pause status
(define-read-only (is-contract-paused)
    (var-get contract-paused)
)

;; Check if contract is authorized
(define-read-only (is-authorized-contract (contract principal))
    (default-to false (map-get? authorized-contracts contract))
)

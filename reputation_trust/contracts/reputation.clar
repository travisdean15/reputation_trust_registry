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

;; Increment user reputation (only authorized contracts/admin)
(define-public (increment-reputation
        (user principal)
        (points uint)
    )
    (begin
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts!
            (or
                (is-eq tx-sender (var-get contract-owner))
                (default-to false (map-get? authorized-contracts tx-sender))
            )
            ERR-UNAUTHORIZED
        )
        (asserts! (> points u0) ERR-INVALID-AMOUNT)
        (match (map-get? user-data user)
            current-data (begin
                (asserts! (> (get staked-amount current-data) u0)
                    ERR-INSUFFICIENT-STAKE
                )
                (let ((new-score (+ (get reputation-score current-data) points)))
                    (map-set user-data user
                        (merge current-data { reputation-score: new-score })
                    )
                    (print {
                        event: "ReputationUpdated",
                        user: user,
                        old-score: (get reputation-score current-data),
                        new-score: new-score,
                    })
                    (ok new-score)
                )
            )
            ERR-USER-NOT-FOUND
        )
    )
)

;; Decrement user reputation (only authorized contracts/admin)
(define-public (decrement-reputation
        (user principal)
        (points uint)
    )
    (begin
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts!
            (or
                (is-eq tx-sender (var-get contract-owner))
                (default-to false (map-get? authorized-contracts tx-sender))
            )
            ERR-UNAUTHORIZED
        )
        (asserts! (> points u0) ERR-INVALID-AMOUNT)
        (match (map-get? user-data user)
            current-data (begin
                (asserts! (> (get staked-amount current-data) u0)
                    ERR-INSUFFICIENT-STAKE
                )
                (let (
                        (current-score (get reputation-score current-data))
                        (new-score (if (<= current-score points)
                            u0
                            (- current-score points)
                        ))
                    )
                    (map-set user-data user
                        (merge current-data { reputation-score: new-score })
                    )
                    (print {
                        event: "ReputationUpdated",
                        user: user,
                        old-score: current-score,
                        new-score: new-score,
                    })
                    (ok new-score)
                )
            )
            ERR-USER-NOT-FOUND
        )
    )
)

;; Apply reputation decay for a user (callable by anyone)
(define-public (decay-reputation (user principal))
    (match (map-get? user-data user)
        current-data (let (
                (current-score (get reputation-score current-data))
                (decay-amount (/ (* current-score (var-get decay-rate)) u100))
                (new-score (if (<= current-score decay-amount)
                    u0
                    (- current-score decay-amount)
                ))
            )
            (map-set user-data user
                (merge current-data {
                    reputation-score: new-score,
                    last-decay-block: stacks-block-height,
                })
            )
            (print {
                event: "ReputationDecayed",
                user: user,
                old-score: current-score,
                new-score: new-score,
                decay-amount: decay-amount,
            })
            (ok new-score)
        )
        ERR-USER-NOT-FOUND
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

;; Get user reputation score
(define-read-only (get-reputation (user principal))
    (match (map-get? user-data user)
        user-info (ok (get reputation-score user-info))
        ERR-USER-NOT-FOUND
    )
)

;; Mint a new reputation badge NFT
(define-public (mint-badge
        (recipient principal)
        (badge-name (string-ascii 64))
        (badge-description (string-ascii 256))
    )
    (let ((badge-id (var-get next-badge-id)))
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts!
            (or
                (is-eq tx-sender (var-get contract-owner))
                (default-to false (map-get? authorized-contracts tx-sender))
            )
            ERR-UNAUTHORIZED
        )
        (match (map-get? user-data recipient)
            user-info (begin
                (asserts!
                    (>= (get reputation-score user-info) MIN-REPUTATION-FOR-BADGE)
                    ERR-INSUFFICIENT-REPUTATION
                )
                (asserts! (is-none (map-get? badge-metadata badge-id))
                    ERR-BADGE-EXISTS
                )
                (try! (nft-mint? reputation-badge badge-id recipient))
                (map-set badge-metadata badge-id {
                    name: badge-name,
                    description: badge-description,
                    creator: tx-sender,
                })
                (map-set user-badges {
                    user: recipient,
                    badge-id: badge-id,
                }
                    true
                )
                (var-set next-badge-id (+ badge-id u1))
                (print {
                    event: "BadgeMinted",
                    recipient: recipient,
                    badge-id: badge-id,
                    name: badge-name,
                    creator: tx-sender,
                })
                (ok badge-id)
            )
            ERR-USER-NOT-FOUND
        )
    )
)

;; Transfer badge NFT to another user
(define-public (transfer-badge
        (badge-id uint)
        (recipient principal)
    )
    (let ((sender tx-sender))
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts! (is-some (map-get? badge-metadata badge-id))
            ERR-BADGE-NOT-FOUND
        )
        (match (nft-get-owner? reputation-badge badge-id)
            current-owner (begin
                (asserts! (is-eq current-owner sender) ERR-UNAUTHORIZED)
                (try! (nft-transfer? reputation-badge badge-id sender recipient))
                (map-delete user-badges {
                    user: sender,
                    badge-id: badge-id,
                })
                (map-set user-badges {
                    user: recipient,
                    badge-id: badge-id,
                }
                    true
                )
                (print {
                    event: "BadgeTransferred",
                    from: sender,
                    to: recipient,
                    badge-id: badge-id,
                })
                (ok true)
            )
            ERR-BADGE-NOT-FOUND
        )
    )
)

;; Burn a badge NFT (only owner or admin)
(define-public (burn-badge (badge-id uint))
    (let ((sender tx-sender))
        (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
        (asserts! (is-some (map-get? badge-metadata badge-id))
            ERR-BADGE-NOT-FOUND
        )
        (match (nft-get-owner? reputation-badge badge-id)
            current-owner (begin
                (asserts!
                    (or
                        (is-eq current-owner sender)
                        (is-eq sender (var-get contract-owner))
                        (default-to false (map-get? authorized-contracts sender))
                    )
                    ERR-UNAUTHORIZED
                )
                (try! (nft-burn? reputation-badge badge-id current-owner))
                (map-delete user-badges {
                    user: current-owner,
                    badge-id: badge-id,
                })
                (print {
                    event: "BadgeBurned",
                    owner: current-owner,
                    badge-id: badge-id,
                    burned-by: sender,
                })
                (ok true)
            )
            ERR-BADGE-NOT-FOUND
        )
    )
)

;; Administrative Functions

;; Set new contract owner (only current owner)
(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (print {
            event: "OwnershipTransferred",
            old-owner: tx-sender,
            new-owner: new-owner,
        })
        (ok true)
    )
)

;; Pause/unpause contract (only owner)
(define-public (set-contract-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set contract-paused paused)
        (print {
            event: "ContractPauseStatusChanged",
            paused: paused,
            changed-by: tx-sender,
        })
        (ok paused)
    )
)

;; Authorize/deauthorize contract to modify reputation (only owner)
(define-public (set-authorized-contract
        (contract-address principal)
        (authorized bool)
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (if authorized
            (map-set authorized-contracts contract-address true)
            (map-delete authorized-contracts contract-address)
        )
        (print {
            event: "ContractAuthorizationChanged",
            contract: contract-address,
            authorized: authorized,
            changed-by: tx-sender,
        })
        (ok authorized)
    )
)

;; Update decay rate (only owner)
(define-public (set-decay-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (asserts! (<= new-rate MAX-DECAY-RATE) ERR-INVALID-AMOUNT)
        (var-set decay-rate new-rate)
        (print {
            event: "DecayRateUpdated",
            old-rate: (var-get decay-rate),
            new-rate: new-rate,
            changed-by: tx-sender,
        })
        (ok new-rate)
    )
)

;; Update minimum stake amount (only owner)
(define-public (set-min-stake-amount (new-amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (asserts! (> new-amount u0) ERR-INVALID-AMOUNT)
        (var-set min-stake-amount new-amount)
        (print {
            event: "MinStakeUpdated",
            old-amount: (var-get min-stake-amount),
            new-amount: new-amount,
            changed-by: tx-sender,
        })
        (ok new-amount)
    )
)

;; Additional Read-Only Functions for Badge System

;; Get badge metadata
(define-read-only (get-badge-metadata (badge-id uint))
    (map-get? badge-metadata badge-id)
)

;; Check if user owns a specific badge
(define-read-only (user-owns-badge
        (user principal)
        (badge-id uint)
    )
    (default-to false
        (map-get? user-badges {
            user: user,
            badge-id: badge-id,
        })
    )
)

;; Get badge owner
(define-read-only (get-badge-owner (badge-id uint))
    (nft-get-owner? reputation-badge badge-id)
)

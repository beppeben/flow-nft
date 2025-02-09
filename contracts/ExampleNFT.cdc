// This is an example implementation of a Flow Non-Fungible Token
// It is not part of the official standard but it assumed to be
// very similar to how many NFTs would implement the core functionality.

import NonFungibleToken from 0xf8d6e0586b0a20c7
import ConstrainedOwnership from 0xf8d6e0586b0a20c7
import MetadataViews from 0xf8d6e0586b0a20c7

pub contract ExampleNFT: NonFungibleToken {

    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        pub let name: String
        pub let description: String
        pub let thumbnail: String
        access(self) let royalties: [MetadataViews.Royalty]

        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: String,
            royalties: [MetadataViews.Royalty]
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.royalties = royalties
        }
    
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                    )
            }
            return nil
        }
    }

    pub resource interface ExampleNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowExampleNFT(id: UInt64): &ExampleNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow ExampleNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: ExampleNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, ConstrainedOwnership.AcceptsSeizable, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // NFTs that can be seized by an external account (lender) in case of default
        access(contract) var seizableNFTs: @{UInt64: NonFungibleToken.NFT}
        access(contract) var seizableBy: {UInt64: Address}

        // store capability to the collection to check that it doesn't get unlinked
        access(self) var capabilityCheck: Capability<&ExampleNFT.Collection{ConstrainedOwnership.AcceptsSeizable}>?
        access(self) var capabilityInit: Bool

        init () {
            self.ownedNFTs <- {}
            self.seizableNFTs <- {}
            self.seizableBy = {}
            self.capabilityCheck = nil
            self.capabilityInit = false
        }

        // initialize link to the collection (can be done only once)
        pub fun initCapability(cap: Capability<&ExampleNFT.Collection{ConstrainedOwnership.AcceptsSeizable}>) {
            if !self.capabilityInit {
                self.capabilityCheck = cap
                self.capabilityInit = true
            }
        }

        // check if the collection is correctly linked
        pub fun checkUse(): Bool {
            return self.capabilityCheck != nil && self.capabilityCheck!.borrow() != nil
        }

        // deposit an NFT which can be seized by the sender
        // (the conditions under which this can happen are defined in the lending contract)
        pub fun depositSeizable(from: AuthAccount, token: @NonFungibleToken.NFT) {
            let token <- token as! @ExampleNFT.NFT
            let id: UInt64 = token.id
            let oldToken <- self.seizableNFTs[id] <- token
            self.seizableBy[id] = from.address
            destroy oldToken
        }

        // claim an asset back by the lender (after a default of payment)
        pub fun seize(from: AuthAccount, seizeID: UInt64): @NonFungibleToken.NFT {
            if self.seizableBy[seizeID] == nil || self.seizableBy[seizeID] != from.address {
                panic("The caller has no rights to seize this asset")
            }
            let token <- self.seizableNFTs.remove(key: seizeID) ?? panic("missing NFT")
            return <-token
        }

        // release the constraint after the loan has been fully repaid
        // now we have full ownership of the asset
        pub fun releaseConstraint(from: AuthAccount, id: UInt64) {
            if self.seizableBy[id] == nil || self.seizableBy[id] != from.address {
                panic("The caller has no rights to release a constraint on this asset")
            }
            self.seizableBy.remove(key: id)
            let token <- self.seizableNFTs.remove(key: id) ?? panic("missing NFT")
            let oldToken <- self.ownedNFTs[id] <- token
            destroy oldToken
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @ExampleNFT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys.concat(self.seizableNFTs.keys)
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            if self.ownedNFTs.containsKey(id) {
                return &self.ownedNFTs[id] as &NonFungibleToken.NFT
            } else {
                return &self.seizableNFTs[id] as &NonFungibleToken.NFT
            }
        }
 
        pub fun borrowExampleNFT(id: UInt64): &ExampleNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &ExampleNFT.NFT
            } else if self.seizableNFTs[id] != nil {
                let ref = &self.seizableNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &ExampleNFT.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            if self.ownedNFTs[id] != nil {
                let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                let exampleNFT = nft as! &ExampleNFT.NFT
                return exampleNFT
            } else {
                let nft = &self.seizableNFTs[id] as auth &NonFungibleToken.NFT
                let exampleNFT = nft as! &ExampleNFT.NFT
                return exampleNFT
            }
        }

        destroy() {
            if (self.seizableNFTs.length > 0) {
                panic("Cannot destroy a collection containing seizable items.")
            }
            destroy self.ownedNFTs
            destroy self.seizableNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {

        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            name: String,
            description: String,
            thumbnail: String,
            royalties: [MetadataViews.Royalty]
        ) {

            // create a new NFT
            var newNFT <- create NFT(
                id: ExampleNFT.totalSupply,
                name: name,
                description: description,
                thumbnail: thumbnail,
                royalties: royalties
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            ExampleNFT.totalSupply = ExampleNFT.totalSupply + UInt64(1)
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/exampleNFTCollection
        self.CollectionPublicPath = /public/exampleNFTCollection
        self.MinterStoragePath = /storage/exampleNFTMinter

        // create a public capability for the collection
        let cap = self.account.link<&ExampleNFT.Collection{NonFungibleToken.CollectionPublic, ExampleNFT.ExampleNFTCollectionPublic, ConstrainedOwnership.AcceptsSeizable}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        collection.initCapability(cap: cap!)
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}

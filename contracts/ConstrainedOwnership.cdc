// Standard that defines cases of constrained ownership of NFTs
// The main example is that of a loan contracted in order to buy an NFT, where
// the NFT is immediately owned by the borrower who can use it for its utility,
// however the lender keeps the right to claim it back until the loan is fully repaid
// (under certain conditions to be defined in the lending contract)

import NonFungibleToken from 0xf8d6e0586b0a20c7

pub contract interface ConstrainedOwnership {

    // A collection implementing this interface accepts the deposit of NFTs
    // which can be claimed back by the sender under certain conditions
    // (typically, a default of payment by the receiver)
    // These seizable assets are nontransferable and non destroyable by the holder
    // until the constraint is released (when the loan is fully repaid)
    pub resource interface AcceptsSeizable {
        // deposit an NFT which can be seized by the sender
        // (the conditions under which this can happen are defined in the lending contract)
        // returns a key to be used to seize the asset or release the constraint
        pub fun depositSeizable(token: @NonFungibleToken.NFT): @AnyResource

        // release the constraint after the loan has been fully repaid
        // now we have full ownership of the asset
        pub fun releaseConstraint(key: @AnyResource)

        // claim an asset back by the lender (after a default of payment)
        pub fun seize(key: @AnyResource): @NonFungibleToken.NFT

        // check if the collection is correctly linked
        pub fun checkUse():  Bool

        // if it is not, make it unusable
        pub fun getIDs(): [UInt64] {
            pre {
                self.checkUse(): "Collection unusable"
            }
        }
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            pre {
                self.checkUse(): "Collection unusable"
            }
        }
    }

    // createEmptyCollection creates an empty Collection
    // and returns it to the caller so that they can own NFTs
    pub fun createEmptySeizableCollection(seizeCap: Capability<&AnyResource{AcceptsSeizable}>?): @NonFungibleToken.Collection {
        post {
            result.getIDs().length == 0: "The created collection must be empty!"
        }
    }

    // key to be used to seize or release the asset
    pub resource SeizeKey {
        pub let id: UInt64
    }
}
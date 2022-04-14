// Standard that defines cases of constrained ownership of NFTs
// The main example is that of a loan contracted in order to buy an NFT, where
// the NFT is immediately owned by the borrower who can use it for its utility,
// however the lender keeps the right to claim it back until the loan is fully repaid
// (under certain conditions to be defined in the lending contract)

import NonFungibleToken from 0xf8d6e0586b0a20c7

pub contract ConstrainedOwnership {

    // A collection implementing this interface accepts the deposit of NFTs
    // which can be claimed back by the sender under certain conditions
    // (typically, a default of payment by the receiver)
    // These seizable assets are nontransferable and non destroyable by the holder
    // until the constraint is released (when the loan is fully repaid)
    pub resource interface AcceptsSeizable {
        // deposit an NFT which can be seized by the sender
        // (the conditions under which this can happen are defined in the lending contract)
        pub fun depositSeizable(from: AuthAccount, token: @NonFungibleToken.NFT)

        // claim an asset back by the lender (after a default of payment)
        pub fun seize(from: AuthAccount, seizeID: UInt64): @NonFungibleToken.NFT

        // release the constraint after the loan has been fully repaid
        // now we have full ownership of the asset
        pub fun releaseConstraint(from: AuthAccount, id: UInt64)
    }
}

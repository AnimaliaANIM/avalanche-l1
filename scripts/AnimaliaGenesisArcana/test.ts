import { StandardMerkleTree } from '@openzeppelin/merkle-tree'
import { randomBytes, randomInt } from 'crypto'
import { ethers } from 'hardhat'

{
  (async function () {
    const signers = await ethers.getSigners()
    const owner = signers[0]
    const provider = owner.provider
    if (!provider) {
      throw new Error('Provider not ready.')
    }
    const { chainId } = await provider.getNetwork()
    const isLocalhost = chainId === 31337n

    console.log('chainId', chainId)
    console.log('owner.address', owner.address)
    console.log('balanceOf owner.address', ethers.formatEther(await provider.getBalance(owner.address)))

    if (!isLocalhost) {
      throw new Error('Not localhost')
    }

    const factory = await ethers.getContractFactory('AnimaliaGenesisArcana')
    const name = 'Animalia Genesis Arcana'
    const symbol = 'ANIM GA'
    const baseURI = ''
    const royaltyRecipient = owner.address
    const royaltyFee = 500
    const arcanaSC = await factory.connect(owner).deploy(name, symbol, baseURI, royaltyRecipient, royaltyFee)

    console.log('arcanaSC deployed', await arcanaSC.getAddress())

    console.log()
    console.log('signers', signers.length)

    const mintWhitelist = signers.map<[string, number]>(s => [s.address, randomInt(10, 11)]).concat([
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
      // [owner.address, 10],
    ])
    // console.log(mintWhitelist)
    const tree = StandardMerkleTree.of(mintWhitelist, ['address', 'uint256'])
    // console.log(tree.length)

    await arcanaSC.setMintMerkleRoot(tree.root)
    console.log('mintMerkleRoot', await arcanaSC.mintMerkleRoot())

    for (const signer of signers) {
      console.log()
      console.log('balanceOf', signer.address, await arcanaSC.balanceOf(signer.address))
      const quota = 10
      const amount = randomInt(1, 11)
      const proof = tree.getProof([signer.address, quota])
      // console.log('proof', proof)

      await arcanaSC.connect(signer)['mint(bytes32[],uint256,uint256)'](proof, quota, amount)

      console.log('balanceOf', signer.address, await arcanaSC.balanceOf(signer.address))
      // break
      console.log('minted', signer.address, await arcanaSC.tokensMinted(tree.root, signer.address))
    }

    for (const signer of signers) {
      console.log()
      const quota = 10
      const amount = BigInt(quota) - await arcanaSC.tokensMinted(tree.root, signer.address)
      console.log('balanceOf', signer.address, await arcanaSC.balanceOf(signer.address), amount)
      const proof = tree.getProof([signer.address, quota])
      // console.log('proof', proof)

      await arcanaSC.connect(signer)['mint(bytes32[],uint256,uint256)'](proof, quota, amount)

      console.log('balanceOf', signer.address, await arcanaSC.balanceOf(signer.address))
      // break
      console.log('minted', signer.address, await arcanaSC.tokensMinted(tree.root, signer.address))
    }

  })()
}
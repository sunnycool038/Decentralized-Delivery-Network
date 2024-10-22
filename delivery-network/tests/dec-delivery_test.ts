
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

const CONTRACT_NAME = "decentralized-delivery-network";

Clarinet.test({
    name: "Ensure that users can create a package",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const sender = accounts.get("wallet_1")!;
        const recipient = accounts.get("wallet_2")!;

        const block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "create-package",
                [
                    types.uint(1), // package-id
                    types.principal(recipient.address),
                    types.uint(1000), // price
                    types.ascii("123 Pickup St"), // pickup location
                    types.ascii("456 Delivery Ave") // delivery location
                ],
                sender.address
            )
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.height, 2);
        assertEquals(block.receipts[0].result.expectOk(), true);
    },
});

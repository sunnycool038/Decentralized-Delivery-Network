
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

Clarinet.test({
    name: "Ensure that couriers can register",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const courier = accounts.get("wallet_3")!;

        const block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "register-courier",
                [types.ascii("John Doe")],
                courier.address
            )
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.height, 2);
        assertEquals(block.receipts[0].result.expectOk(), true);
    },
});

Clarinet.test({
    name: "Ensure that registered couriers can accept packages",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const sender = accounts.get("wallet_1")!;
        const recipient = accounts.get("wallet_2")!;
        const courier = accounts.get("wallet_3")!;

        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "register-courier",
                [types.ascii("John Doe")],
                courier.address
            ),
            Tx.contractCall(
                CONTRACT_NAME,
                "create-package",
                [
                    types.uint(1),
                    types.principal(recipient.address),
                    types.uint(1000),
                    types.ascii("123 Pickup St"),
                    types.ascii("456 Delivery Ave")
                ],
                sender.address
            )
        ]);

        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "accept-package",
                [types.uint(1)],
                courier.address
            )
        ]);

        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), true);
    },
});

Clarinet.test({
    name: "Ensure that couriers can complete deliveries and receive payment",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const sender = accounts.get("wallet_1")!;
        const recipient = accounts.get("wallet_2")!;
        const courier = accounts.get("wallet_3")!;
        const price = 1000;

        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "register-courier",
                [types.ascii("John Doe")],
                courier.address
            ),
            Tx.contractCall(
                CONTRACT_NAME,
                "create-package",
                [
                    types.uint(1),
                    types.principal(recipient.address),
                    types.uint(price),
                    types.ascii("123 Pickup St"),
                    types.ascii("456 Delivery Ave")
                ],
                sender.address
            )
        ]);

        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "accept-package",
                [types.uint(1)],
                courier.address
            )
        ]);

        const initialBalance = chain.getAssetsMaps().assets["STX"][courier.address];

        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "complete-delivery",
                [types.uint(1)],
                courier.address
            )
        ]);

        const finalBalance = chain.getAssetsMaps().assets["STX"][courier.address];
        assertEquals(finalBalance - initialBalance, price);
        assertEquals(block.receipts[0].result.expectOk(), true);
    },
});

Clarinet.test({
    name: "Ensure that users can rate couriers",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const courier = accounts.get("wallet_3")!;
        const user = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "register-courier",
                [types.ascii("John Doe")],
                courier.address
            )
        ]);

        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "rate-courier",
                [
                    types.principal(courier.address),
                    types.uint(5)
                ],
                user.address
            )
        ]);

        assertEquals(block.receipts[0].result.expectOk(), true);
    },
});

Clarinet.test({
    name: "Ensure that packages can be cancelled",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const sender = accounts.get("wallet_1")!;
        const recipient = accounts.get("wallet_2")!;

        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "create-package",
                [
                    types.uint(1),
                    types.principal(recipient.address),
                    types.uint(1000),
                    types.ascii("123 Pickup St"),
                    types.ascii("456 Delivery Ave")
                ],
                sender.address
            )
        ]);

        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "cancel-package",
                [types.uint(1)],
                sender.address
            )
        ]);

        assertEquals(block.receipts[0].result.expectOk(), true);
    },
});

Clarinet.test({
    name: "Ensure that couriers can update package location",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const sender = accounts.get("wallet_1")!;
        const recipient = accounts.get("wallet_2")!;
        const courier = accounts.get("wallet_3")!;

        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "register-courier",
                [types.ascii("John Doe")],
                courier.address
            ),
            Tx.contractCall(
                CONTRACT_NAME,
                "create-package",
                [
                    types.uint(1),
                    types.principal(recipient.address),
                    types.uint(1000),
                    types.ascii("123 Pickup St"),
                    types.ascii("456 Delivery Ave")
                ],
                sender.address
            )
        ]);

        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "accept-package",
                [types.uint(1)],
                courier.address
            )
        ]);

        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "update-package-location",
                [
                    types.uint(1),
                    types.ascii("789 Current Location St")
                ],
                courier.address
            )
        ]);

        assertEquals(block.receipts[0].result.expectOk(), true);
    },
});

Clarinet.test({
    name: "Ensure that users can file disputes",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const sender = accounts.get("wallet_1")!;
        const recipient = accounts.get("wallet_2")!;

        let block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "create-package",
                [
                    types.uint(1),
                    types.principal(recipient.address),
                    types.uint(1000),
                    types.ascii("123 Pickup St"),
                    types.ascii("456 Delivery Ave")
                ],
                sender.address
            )
        ]);

        block = chain.mineBlock([
            Tx.contractCall(
                CONTRACT_NAME,
                "file-dispute",
                [
                    types.uint(1),
                    types.ascii("Package not received")
                ],
                recipient.address
            )
        ]);

        assertEquals(block.receipts[0].result.expectOk(), true);
    },
});

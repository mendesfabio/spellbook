{{
    config(
        schema = 'tornado_cash_ethereum',
        alias = 'airdrop_claims',
        materialized = 'table',
        file_format = 'delta',
        tags=['static'],
        unique_key = ['recipient', 'tx_hash', 'evt_index'],
        post_hook='{{ expose_spells(\'["ethereum"]\',
                                "project",
                                "tornado_cash",
                                \'["hildobby"]\') }}'
    )
}}

{% set torn_token_address = '0x77777feddddffc19ff86db637967013e6c6a116c' %}

WITH early_price AS (
    SELECT MIN(minute) AS minute
    , MIN_BY(price, minute) AS price
    FROM {{ source('prices', 'usd') }}
    WHERE blockchain = 'ethereum'
    AND contract_address = {{torn_token_address}}
    )

SELECT 'ethereum' AS blockchain
, t.evt_block_time AS block_time
, t.evt_block_number AS block_number
, 'tornado_cash' AS project
, 1 AS airdrop_number
, t."from" AS recipient
, t.contract_address
, t.evt_tx_hash AS tx_hash
, t.value AS amount_raw
, CAST(t.value/POWER(10, 18) AS double) AS amount_original
, CASE WHEN t.evt_block_time >= (SELECT minute FROM early_price) THEN CAST(pu.price*t.value/POWER(10, 18) AS double)
    ELSE CAST((SELECT price FROM early_price)*t.value/POWER(10, 18) AS double)
    END AS amount_usd
, from_hex('{{torn_token_address}}') AS token_address
, 'TORN' AS token_symbol
, t.evt_index
FROM {{ source('erc20_ethereum', 'evt_Transfer') }} t
LEFT JOIN {{ source('prices','usd_forward_fill') }} pu ON pu.blockchain = 'ethereum'
    AND pu.contract_address = {{torn_token_address}}
    AND pu.minute=date_trunc('minute', t.evt_block_time)
WHERE t.evt_block_time BETWEEN TIMESTAMP '2020-12-18' AND TIMESTAMP '2021-12-13'
    AND t.contract_address = {{torn_token_address}}

USE cartlens;
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM order_payments;
SELECT COUNT(*) FROM order_reviews;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM sellers;
SELECT COUNT(*) FROM geolocation;
SELECT COUNT(*) FROM category_name_translation;

-- ====================================================================================================
-- #1 How large is the business in terms of orders, customers, and revenue?
-- UNIQUE ORDERS
SELECT COUNT(DISTINCT o.order_id) AS valid_orders
FROM order_payments op
JOIN orders o
    ON op.order_id = o.order_id
WHERE o.order_status <> 'canceled';

-- TOTAL REVENUE
SELECT SUM(OP.payment_value) AS revenue
FROM order_payments OP
JOIN orders O 
	ON OP.order_id = O.order_id 
WHERE O.order_status <> 'canceled';

-- UNIQUE CUSTOMERS
SELECT COUNT(customer_unique_id) AS total_customers FROM customers;
SELECT COUNT(DISTINCT C.customer_unique_id) AS unique_customers 
FROM orders O
JOIN customers C
	ON O.customer_id = C.customer_id;
    
-- AOV
SELECT SUM(OP.payment_value) / COUNT(DISTINCT O.order_iD) AS AOV 
FROM order_payments OP
JOIN orders O 
	ON OP.order_id = O.order_id
WHERE O.order_status <> 'canceled';

-- Analysis:
-- 1. The dataset contains 99,441 total orders.
-- 2. There are 98,815 non-cancelled orders with
--    payment records.
-- 3. The platform has 96,096 unique customers who
--    placed orders.
-- 4. Total payment value from non-cancelled orders
--    is 15,865,616.52.
-- 5. The payment-based average order value (AOV)
--    is approximately 160.56 per eligible order.
-- ====================================================================================================
-- #2 Monthly Sales Trend
-- Problem: How are sales changing over time?

-- No of order each month
SELECT 
	YEAR(order_purchase_timestamp) AS YEAR, 
	MONTH(order_purchase_timestamp) AS MONTH, 
    COUNT(order_id) AS NO_OF_ORDERS 
FROM orders
WHERE order_status <> 'CANCELED'
GROUP BY 
	YEAR(order_purchase_timestamp), 
	MONTH(order_purchase_timestamp)
ORDER BY 
	YEAR(order_purchase_timestamp),
	MONTH(order_purchase_timestamp);
    
-- Revenue of each month
SELECT 
	YEAR(O.order_purchase_timestamp) AS YEAR, 
    MONTH(O.order_purchase_timestamp) AS MONTH, 
    SUM(OP.payment_value) AS REVENUE_PER_MONTH 
FROM orders O 
JOIN order_payments OP
	ON O.order_id = OP.order_id
    WHERE O.order_status <> 'canceled'
GROUP BY 
	YEAR(O.order_purchase_timestamp), 
	MONTH(O.order_purchase_timestamp)
ORDER BY 
	YEAR(O.order_purchase_timestamp),
    MONTH(O.order_purchase_timestamp);

-- AOV per month
SELECT 
	YEAR(O.order_purchase_timestamp) AS YEAR, 
    MONTH(O.order_purchase_timestamp) AS MONTH, 
    SUM(OP.payment_value)/COUNT(DISTINCT O.order_id) AS AOV_PER_MONTH 
FROM orders O 
JOIN order_payments OP
	ON O.order_id = OP.order_id
    WHERE O.order_status <> 'canceled'
GROUP BY 
	YEAR(O.order_purchase_timestamp), 
	MONTH(O.order_purchase_timestamp)
ORDER BY 
	YEAR(O.order_purchase_timestamp),
    MONTH(O.order_purchase_timestamp);

-- M-O-M
WITH monthly_revenue AS(
	SELECT 
		YEAR(O.order_purchase_timestamp) AS YEAR, 
		MONTH(O.order_purchase_timestamp) AS MONTH, 
		SUM(OP.payment_value) AS REVENUE 
	FROM orders O 
	JOIN order_payments OP
		ON O.order_id = OP.order_id
		WHERE O.order_status <> 'canceled'
	GROUP BY 
		YEAR(O.order_purchase_timestamp), 
		MONTH(O.order_purchase_timestamp)
	ORDER BY 
		YEAR(O.order_purchase_timestamp),
		MONTH(O.order_purchase_timestamp)
)
SELECT
	YEAR,
    MONTH,
    LAG(REVENUE) OVER (
		ORDER BY YEAR, MONTH 
    ) AS PREV_MONTH_REVENUE
    FROM MONTHLY_REVENUE;
    
-- M-O-M in %
WITH monthly_revenue AS (
    SELECT 
        YEAR(O.order_purchase_timestamp) AS YEAR, 
        MONTH(O.order_purchase_timestamp) AS MONTH, 
        SUM(OP.payment_value) AS REVENUE 
    FROM orders O 
    JOIN order_payments OP
        ON O.order_id = OP.order_id
    WHERE O.order_status <> 'canceled'
    GROUP BY 
        YEAR(O.order_purchase_timestamp), 
        MONTH(O.order_purchase_timestamp)
),

monthly_with_prev AS (
    SELECT
        YEAR,
        MONTH,
        REVENUE,
        LAG(REVENUE) OVER (
            ORDER BY YEAR, MONTH
        ) AS PREV_MONTH_REVENUE
    FROM monthly_revenue
)

SELECT
    YEAR,
    MONTH,
    REVENUE,
    PREV_MONTH_REVENUE,
    ROUND(
        (REVENUE - PREV_MONTH_REVENUE) 
        / PREV_MONTH_REVENUE * 100,
        2
    ) AS MOM_GROWTH
FROM monthly_with_prev
ORDER BY YEAR, MONTH;

-- Analysis:
-- 1. Monthly order volume and payment value increased
--    substantially throughout much of 2017.
-- 2. November 2017 recorded the highest monthly payment
--    value, approximately 1,187,224.36, with 7,507
--    non-cancelled orders.
-- 3. Monthly payment value remained relatively high
--    during the first eight months of 2018 compared
--    with the beginning of 2017.
-- 4. Monthly average payment value per order generally
--    remained between 150 and 170 during the main
--    analysis period, suggesting that changes in total
--    payment value were largely associated with changes
--    in order volume.
-- 5. November 2017 experienced a month-over-month
--    payment-value increase of 53.57%, followed by a
--    decrease of 26.30% in December 2017.
-- 6. September 2016 and September 2018 contain very few
--    recorded orders and should not be compared directly
--    with complete months.
-- 7. September 2018 recorded a 99.98% month-over-month
--    decline in payment value, but this comparison is
--    misleading because the month contains only one
--    non-cancelled order in the dataset.

-- ====================================================================================================
-- #3 Which product categories generate the most revenue?
SELECT 
	PCNT.PRODUCT_CATEGORY_NAME_ENGLISH,
	COUNT(DISTINCT OI.ORDER_ID) AS TOTAL_ORDERS,
    SUM(OI.PRICE) AS REVENUE,
    ROUND((SUM(OI.PRICE) / COUNT(DISTINCT OI.ORDER_ID)), 2) AS AVG_CATEGORY_SALES_PER_ORDER
    FROM PRODUCTS P 
    JOIN order_items OI 
		ON P.PRODUCT_ID = OI.PRODUCT_ID
	JOIN ORDERS O 
		ON O.ORDER_ID = OI.ORDER_ID AND O.ORDER_STATUS = 'delivered'
    JOIN CATEGORY_NAME_TRANSLATION PCNT
		ON P.PRODUCT_CATEGORY_NAME = PCNT.PRODUCT_CATEGORY_NAME
	GROUP BY PCNT.PRODUCT_CATEGORY_NAME_ENGLISH
	ORDER BY REVENUE DESC;
    
-- Analysis:
-- 1. Health & Beauty generated the highest item sales,
--    totaling 1,233,131.72 across 8,647 orders.
-- 2. Watches & Gifts ranked second, generating
--    1,166,176.98 across 5,495 orders.
-- 3. Bed/Bath/Table recorded the highest order volume,
--    with 9,272 orders and item sales of 1,023,434.76.
-- 4. Computers recorded the highest average category
--    sales per order at 1,235.50, despite appearing
--    in only 177 orders.
-- 5. Health & Beauty leads in total item sales, while
--    Bed/Bath/Table leads in order volume. This shows
--    that category performance differs depending on
--    the metric used.
-- 6. Categories such as Small Appliances and Musical
--    Instruments also recorded relatively high average
--    category sales per order, but with lower order
--    volumes than the leading categories.
	
-- ====================================================================================================
-- #4 Which payment methods do customers use most?
SELECT
	COUNT(DISTINCT(O.ORDER_ID)) AS TOTAL_ORDER,
    OP.PAYMENT_TYPE,
    SUM(OP.PAYMENT_VALUE) AS TOTAL_PAYMENT,
    ROUND(
		(SUM(OP.PAYMENT_VALUE) / 
        (SELECT SUM(OP2.PAYMENT_VALUE)
        FROM ORDER_PAYMENTs OP2
        JOIN ORDERS O2
			ON OP2.ORDER_ID = O2.ORDER_ID AND O2.ORDER_STATUS = 'delivered'
            ) * 100 )
            , 2
    ) AS PAYMENT_SHARE_PARCENT
    FROM ORDER_PAYMENTS OP
    JOIN ORDERS O 
		ON OP.ORDER_ID = O.ORDER_ID AND O.ORDER_STATUS = 'delivered'
	GROUP BY OP.PAYMENT_TYPE
	ORDER BY TOTAL_ORDER DESC;
        
-- Analysis:
-- 1. Credit cards were the most widely used payment
--    method, appearing in 74,304 delivered orders and
--    accounting for 78.46% of total payment value.
-- 2. Boleto ranked second, appearing in 19,191 delivered
--    orders and contributing 17.96% of total payment
--    value.
-- 3. Vouchers appeared in 3,679 delivered orders and
--    accounted for 2.22% of total payment value.
-- 4. Debit cards appeared in 1,485 delivered orders and
--    contributed 1.35% of total payment value.
-- 5. Credit cards and boleto together accounted for
--    96.42% of total payment value, showing that these
--    two methods dominated the payment mix.
        
-- ====================================================================================================
-- #5 Which states generate the most sales?
SELECT 
	C.CUSTOMER_STATE,
	COUNT(DISTINCT C.CUSTOMER_UNIQUE_ID) AS NO_OF_CUSTOMERS,
    COUNT(DISTINCT O.ORDER_ID) AS TOTAL_ORDERS,
    SUM(OI.PRICE) AS TOTAL_AMOUNT
    FROM CUSTOMERS C 
    JOIN ORDERS O 
		ON C.CUSTOMER_ID = O.CUSTOMER_ID AND O.ORDER_STATUS = "delivered"
	JOIN ORDER_ITEMS OI 
		ON O.ORDER_ID = OI.ORDER_ID
    GROUP BY C.CUSTOMER_STATE
    ORDER BY TOTAL_AMOUNT DESC;

-- Analysis:
-- 1. São Paulo (SP) generated the highest item sales.
-- 2. SP's item sales were approximately 2.88 times RJ's.
-- 3. RJ had higher average item sales per delivered order
--    than SP among the top five states.

-- ====================================================================================================
-- #6 Which customers make repeat purchases?
SELECT
	C.CUSTOMER_UNIQUE_ID,
    COUNT(DISTINCT O.ORDER_ID) AS NO_OF_ORDERS,
    SUM(OI.PRICE) AS TOTAL_AMOUNT
    FROM CUSTOMERS C 
    JOIN ORDERS O 
		ON C.CUSTOMER_ID = O.CUSTOMER_ID AND O.ORDER_STATUS = 'delivered'
	JOIN ORDER_ITEMS OI 
		ON OI.ORDER_ID = O.ORDER_ID
	GROUP BY C.CUSTOMER_UNIQUE_ID
    HAVING NO_OF_ORDERS > 1
    ORDER BY TOTAL_AMOUNT DESC;
    
-- Analysis:
-- 1. The most frequent repeat customer placed 15 delivered orders.
-- 2. The highest item sales among the displayed customers was 7,388.00
--    from only 2 delivered orders.
-- 3. Order frequency and total item sales measure different aspects
--    of customer value.

-- ====================================================================================================
-- Q7: Which product categories generate the highest average sales per order?
SELECT
	CNT.PRODUCT_CATEGORY_NAME_ENGLISH,
    COUNT(DISTINCT OI.ORDER_ID) AS NO_OF_ORDERS,
    SUM(OI.PRICE) AS TOTAL_AMOUNT,
    ROUND((
    SUM(OI.PRICE)/COUNT(DISTINCT OI.ORDER_ID)
    ), 2
    ) AS AVG_CATEGORY_SALES_PER_ORDER
    FROM ORDER_ITEMS OI 
    JOIN PRODUCTS P 
		ON OI.PRODUCT_ID = P.PRODUCT_ID 
	JOIN ORDERS O 
		ON OI.ORDER_ID = O.ORDER_ID AND O.ORDER_STATUS = 'delivered'
	JOIN CATEGORY_NAME_TRANSLATION CNT
		ON P.PRODUCT_CATEGORY_NAME = CNT.PRODUCT_CATEGORY_NAME
	GROUP BY CNT.PRODUCT_CATEGORY_NAME_ENGLISH
    ORDER BY TOTAL_AMOUNT DESC;

-- Analysis:
-- 1. Computers has the highest average category sales
--    per order at 1,235.50.
-- 2. Health and beauty generates the highest total
--    item sales at 1,233,131.72.
-- 3. Bed, bath and table has the highest order volume
--    with 9,272 delivered orders.
-- 4. Category performance differs depending on whether
--    we measure order volume, total sales, or average sales per order.

-- ====================================================================================================
-- Q8: Which sellers generate the highest sales?
SELECT
	S.SELLER_ID,
    COUNT(DISTINCT OI.ORDER_ID) AS NO_OF_ORDERS,
    SUM(OI.PRICE) AS TOTAL_AMOUNT,
    ROUND(
	SUM(OI.PRICE) / COUNT(DISTINCT OI.ORDER_ID),
	2
    ) AS AVG_SALES_PER_ORDER
    FROM SELLERS S 
    JOIN ORDER_ITEMS OI 
		ON S.SELLER_ID = OI.SELLER_ID
	JOIN ORDERS O 
		ON OI.ORDER_ID = O.ORDER_ID AND O.ORDER_STATUS = 'delivered'
	GROUP BY S.SELLER_ID
	ORDER BY AVG_SALES_PER_ORDER DESC;
        
-- Analysis:
-- 1. The highest-sales seller generated 226,987.93 across 
--    1,124 delivered orders.
-- 2. Another seller generated 217,940.44 across
--    only 348 orders, with higher average sales per order.
-- 3. The seller with the most delivered orders was not
--    the seller with the highest total item sales.
-- 4. Sellers with very few orders can rank highly in
--    average sales per order because of individual high-value orders.

-- ====================================================================================================
-- #9. How long does delivery take, and which states experience longer delivery times?
SELECT
	C.CUSTOMER_STATE,
    COUNT(DISTINCT O.ORDER_ID) AS TOTAL_ORDERS,
    ROUND(
        AVG(DATEDIFF(
            O.ORDER_DELIVERED_CUSTOMER_DATE,
            O.ORDER_PURCHASE_TIMESTAMP
        )), 2
    ) AS AVG_DELIVERY_TIME,
    MAX(DATEDIFF(
		O.ORDER_DELIVERED_CUSTOMER_DATE, 
        O.ORDER_PURCHASE_TIMESTAMP
	)) AS MAX_DELIVERY_TIME,
	MIN(DATEDIFF(
		O.ORDER_DELIVERED_CUSTOMER_DATE, 
        O.ORDER_PURCHASE_TIMESTAMP
	)) AS MIN_DELIVERY_TIME
    FROM CUSTOMERS C 
    JOIN ORDERS O 
		ON C.CUSTOMER_ID = O.CUSTOMER_ID AND O.ORDER_STATUS = 'delivered'
	GROUP BY C.CUSTOMER_STATE
	ORDER BY AVG_DELIVERY_TIME DESC;
    
-- Analysis:
-- 1. SP had the shortest average delivery time at 8.70 days
--    across 40,501 delivered orders.
-- 2. RR had the longest average delivery time at 29.34 days,
--    but the result was based on only 41 orders.
-- 3. RJ averaged 15.24 days across 12,350 delivered orders,
--    compared with 8.70 days in SP.
-- 4. Delivery-time differences warrant further investigation
--    into logistics and regional delivery performance.

-- ====================================================================================================
-- #10 Are customers satisfied with their purchases?
SELECT
    REVIEW_SCORE,
    COUNT(REVIEW_SCORE) AS NO_OF_REVIEWS,
    ROUND(AVG(REVIEW_SCORE), 2) AS OVERALL_AVERAGE_SCORE,
    ROUND(
        COUNT(REVIEW_SCORE) * 100.0 /
        (SELECT COUNT(REVIEW_SCORE) FROM ORDER_REVIEWS),
        2
    ) AS REVIEW_PERCENTAGE
FROM ORDER_REVIEWS
GROUP BY REVIEW_SCORE
ORDER BY NO_OF_REVIEWS DESC;

-- Analysis:
-- 1. Five-star reviews accounted for 57.78% of reviews.
-- 2. Approximately 77.07% of reviews received 4 or 5 stars.
-- 3. Approximately 14.69% of reviews received 1 or 2 stars.
-- 4. The overall average review score was approximately 4.09/5.
-- 5. Further analysis is needed to identify factors
--    associated with low review scores.

-- ====================================================================================================
-- #11 Does freight cost vary across product categories?
SELECT 
	CNT.PRODUCT_CATEGORY_NAME_ENGLISH,
    COUNT(DISTINCT O.ORDER_ID) AS NO_OF_ORDERS,
    SUM(OI.FREIGHT_VALUE) AS FREIGHT_VALUE,
    AVG(OI.FREIGHT_VALUE) AS AVG_FREIGHT_VALUE
    FROM PRODUCTS P 
    JOIN CATEGORY_NAME_TRANSLATION CNT
		ON P.PRODUCT_CATEGORY_NAME = CNT.PRODUCT_CATEGORY_NAME
	JOIN ORDER_ITEMS OI 
		ON P.PRODUCT_ID = OI.PRODUCT_ID
	JOIN ORDERS O 
		ON OI.ORDER_ID = O.ORDER_ID AND O.ORDER_STATUS = 'delivered'
	GROUP BY CNT.PRODUCT_CATEGORY_NAME_ENGLISH
    ORDER BY AVG_FREIGHT_VALUE DESC;
    
-- Analysis:
-- 1. Bed, bath and table had the highest total freight
--    value at 201,774.50.
-- 2. Computers had the highest average freight per item
--    at 48.57, across 177 delivered orders.
-- 3. Office furniture had 67,057.05 in total freight
--    value and an average freight value of 40.20.
-- 4. Total freight and average freight identify different
--    aspects of category-level shipping costs.

-- ====================================================================================================
-- #12 Do longer delivery times correspond to lower review scores?
WITH DELIVERYXREVIEW AS( 
	SELECT
		O.ORDER_ID,
		DATEDIFF(O.ORDER_DELIVERED_CUSTOMER_DATE, O.ORDER_PURCHASE_TIMESTAMP) AS DELIVERY_TIME,
		ORS.REVIEW_SCORE
		FROM ORDERS O 
		JOIN ORDER_REVIEWS ORS
			ON O.ORDER_ID = ORS.ORDER_ID
		WHERE O.ORDER_STATUS = 'delivered'
			AND O.ORDER_DELIVERED_CUSTOMER_DATE IS NOT NULL
			AND ORS.REVIEW_SCORE IS NOT NULL
)
SELECT 
	CASE
		WHEN DELIVERY_TIME <= 7 THEN "0-7 DAYS"
		WHEN DELIVERY_TIME <= 14 THEN "8-14 DAYS"
		WHEN DELIVERY_TIME <= 21 THEN "15-21 DAYS"
		ELSE "MORE THAN 21 DAYS"
        END AS DELIVERY_INTERVAL,
	COUNT(DISTINCT ORDER_ID) AS NO_OF_ORDERS,
	AVG(REVIEW_SCORE) AS AVG_REVIEW
    FROM DELIVERYXREVIEW
    GROUP BY DELIVERY_INTERVAL
    ORDER BY AVG_REVIEW DESC;
    
-- Analysis:
-- 1. Orders delivered within 7 days averaged 4.41/5.
-- 2. Orders delivered within 8–14 days averaged 4.30/5.
-- 3. Orders delivered within 15–21 days averaged 4.12/5.
-- 4. Orders taking more than 21 days averaged 3.06/5.
-- 5. Longer delivery durations were associated with
--    lower average review scores.

-- ====================================================================================================
-- #13 What is the distribution of order statuses?

SELECT
    ORDER_STATUS,
    COUNT(*) AS NO_OF_ORDERS,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM ORDERS),
        2
    ) AS ORDER_STATUS_PERCENTAGE
FROM ORDERS
GROUP BY ORDER_STATUS
ORDER BY NO_OF_ORDERS DESC;

-- Analysis:
-- 1. Delivered orders accounted for 97.02% of all orders.
-- 2. Canceled orders accounted for 0.63%.
-- 3. Unavailable orders accounted for 0.61%.
-- 4. Canceled and unavailable orders totaled 1,234,
--    approximately 1.24% of all orders.
-- 5. Orders in intermediate statuses may warrant further
--    investigation into their lifecycle and timing.

-- ====================================================================================================
-- What percentage of customers place repeat orders?
-- all unique customers
SELECT
    COUNT(DISTINCT C.CUSTOMER_UNIQUE_ID) AS TOTAL_UNIQUE_CUSTOMERS
FROM CUSTOMERS C
JOIN ORDERS O
    ON C.CUSTOMER_ID = O.CUSTOMER_ID
WHERE O.ORDER_STATUS = 'delivered';

-- repeat customers
SELECT
    C.CUSTOMER_UNIQUE_ID,
    COUNT(DISTINCT O.ORDER_ID) AS NO_OF_ORDERS
FROM CUSTOMERS C
JOIN ORDERS O
    ON C.CUSTOMER_ID = O.CUSTOMER_ID
WHERE O.ORDER_STATUS = 'delivered'
GROUP BY C.CUSTOMER_UNIQUE_ID
HAVING COUNT(DISTINCT O.ORDER_ID) > 1
ORDER BY NO_OF_ORDERS DESC;

-- repeat customer rate
WITH CUSTOMER_ORDERS AS (
    SELECT
        C.CUSTOMER_UNIQUE_ID,
        COUNT(DISTINCT O.ORDER_ID) AS NO_OF_ORDERS
    FROM CUSTOMERS C
    JOIN ORDERS O
        ON C.CUSTOMER_ID = O.CUSTOMER_ID
    WHERE O.ORDER_STATUS = 'delivered'
    GROUP BY C.CUSTOMER_UNIQUE_ID
)
SELECT
    COUNT(*) AS TOTAL_UNIQUE_CUSTOMERS,
    SUM(CASE
        WHEN NO_OF_ORDERS > 1 THEN 1
        ELSE 0
    END) AS REPEAT_CUSTOMERS,
    ROUND(
        SUM(CASE
            WHEN NO_OF_ORDERS > 1 THEN 1
            ELSE 0
        END) * 100.0 / COUNT(*),
        2
    ) AS REPEAT_CUSTOMER_RATE_PERCENT
FROM CUSTOMER_ORDERS;

-- Analysis
-- 1. Only 3.00% of customers with at least one delivered order 
-- placed multiple delivered orders in the available dataset. 
-- 2. The remaining 97.00% placed only one delivered order during 
-- the observed period.
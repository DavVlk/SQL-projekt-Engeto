-- DISOCRD: davidw.5796


-- vytvoření 1. tabulky se mzdami a počty zaměstnanců v jednotlivých odvětvích
CREATE OR REPLACE TABLE t_payroll_data AS
SELECT  
	cp.payroll_year,
	ROUND(AVG(cp.value),0) AS avg_value, 
	cpvt.name AS value_type, 
	cpu.name AS payroll_unit, 
	cpc.name AS calculation_code, 
	cpib.name AS industry_branch 
FROM czechia_payroll cp 
LEFT JOIN czechia_payroll_calculation cpc 
	ON cp.calculation_code = cpc.code 
LEFT JOIN czechia_payroll_industry_branch cpib 
	ON cp.industry_branch_code = cpib.code 
LEFT JOIN czechia_payroll_unit cpu 
	ON cp.unit_code = cpu.code 
LEFT JOIN czechia_payroll_value_type cpvt 
	ON cp.value_type_code = cpvt.code
WHERE cp.value IS NOT NULL 
	AND cp.payroll_year > '2005' 
	AND cp.payroll_year < '2019'
	AND cpc.name = 'přepočtený'
GROUP BY payroll_year, industry_branch, value_type, payroll_unit
;


SELECT *
FROM t_payroll_data t1
;

-- vytvoření 2. tabulky s cenami potravin, groupnuté na roky a potraviny
CREATE OR REPLACE TABLE t_food_data AS
SELECT 
	YEAR(cp2.date_from) AS value_year,
	ROUND(AVG(cp2.value),2) AS avg_price_of_food,
	cpc2.name AS type_of_food,
	cpc2.price_value,
	cpc2.price_unit
FROM czechia_price cp2 
LEFT JOIN czechia_price_category cpc2 
	ON cp2.category_code = cpc2.code 
LEFT JOIN czechia_region cr 
	ON cp2.region_code = cr.code
GROUP BY type_of_food, value_year
ORDER BY type_of_food, value_year
;
	
SELECT *
FROM t_food_data t2;

-- vytvoření výsledné primární tabulky, kde je spojení 1. a 2. tabulky dle roků
CREATE OR REPLACE TABLE t_david_wolf_project_sql_primary_final AS
SELECT *
FROM t_tab1 t1
LEFT JOIN t_tab2 t2
	ON t1.payroll_year = t2.value_year
;
	
SELECT *
FROM t_david_wolf_project_sql_primary_final f1
;

-- vytvoření  vedlejší tabulky pro dodatečná data o dalších evropských státech
CREATE OR REPLACE TABLE t_david_wolf_project_SQL_secondary_final AS
SELECT c.*, e.YEAR, e.GDP, e.gini, e.taxes
FROM economies e 
LEFT JOIN countries c 
	ON e.country = c.country
WHERE c.country IN ('Austria', 'Belgium', 'Bulgaria', 'Croatia', 'Cyprus', 'Czech Republic', 'Denmark', 'Estonia', 'Finland', 'France', 'Germany', 'Greece', 'Hungary', 'Ireland', 'Italy', 'Latvia', 'Lithuania', 'Luxembourg', 'Malta', 'Netherlands', 'Poland', 'Portugal', 'Romania', 'Slovakia', 'Slovenia', 'Spain', 'Sweden')
	AND e.YEAR > '2005' AND e.YEAR < '2019'
;


SELECT *
FROM t_david_wolf_project_sql_secondary_final f2 
;

-- 1. Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
SELECT 
	f1.industry_branch,
	f1.payroll_year,
	ROUND(AVG(f1.avg_value),0) AS average_value,
	f2.payroll_year AS last_year,
	f2.average_value_last_year,
	ROUND(AVG(f1.avg_value) - f2.average_value_last_year,0) AS difference
FROM t_david_wolf_project_sql_primary_final f1
JOIN (
	SELECT f1.payroll_year, f1.industry_branch, ROUND(AVG(f1.avg_value),0) AS average_value_last_year
	FROM t_david_wolf_project_sql_primary_final f1
	WHERE f1.industry_branch IS NOT NULL 
	AND f1.value_type = 'Průměrná hrubá mzda na zaměstnance'
	GROUP BY f1.payroll_year, f1.industry_branch
	) f2
	ON f1.payroll_year = f2.payroll_year +1
	AND f1.industry_branch = f2.industry_branch
WHERE f1.industry_branch IS NOT NULL 
	AND f1.value_type = 'Průměrná hrubá mzda na zaměstnance'
GROUP BY f1.payroll_year, f1.industry_branch
ORDER BY difference
;


-- 2. Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?
SELECT 
	f1.payroll_year,
	ROUND(AVG(f1.avg_value),0) AS avg_payroll,
	f2.avg_price_of_food AS avg_price_of_milk,
	f2.type_of_food,
	f3.avg_price_of_food AS avg_price_of_bread,
	f3.type_of_food, 
	ROUND((AVG(f1.avg_value))/f2.avg_price_of_food,0) AS liters_of_milk,
	ROUND((AVG(f1.avg_value))/f3.avg_price_of_food,0) AS pieces_of_bread
FROM t_david_wolf_project_sql_primary_final f1
JOIN (
SELECT 
	f1.payroll_year, 
	ROUND(AVG(f1.avg_price_of_food),2) AS avg_price_of_food, 
	f1.type_of_food
FROM t_david_wolf_project_sql_primary_final f1
WHERE f1.type_of_food LIKE '%Mléko%'
	AND f1.payroll_year IN ('2006','2018')
	GROUP BY f1.type_of_food, f1.payroll_year
 ) f2
 	ON f1.payroll_year = f2.payroll_year
JOIN (
SELECT 
	f1.payroll_year, 
	ROUND(AVG(f1.avg_price_of_food),2) AS avg_price_of_food, 
	f1.type_of_food
FROM t_david_wolf_project_sql_primary_final f1
WHERE f1.type_of_food LIKE '%Chléb%'
	AND f1.payroll_year IN ('2006','2018')
	GROUP BY f1.type_of_food, f1.payroll_year
 ) f3
 	ON f1.payroll_year = f3.payroll_year
 WHERE f1.value_type = 'Průměrná hrubá mzda na zaměstnance'
	AND f1.payroll_year IN ('2006','2018')
GROUP BY f1.payroll_year
;
-- 3.Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?
SELECT 
	f1.type_of_food,
	f1.value_year, 
	AVG(f1.avg_price_of_food) AS avg_price_of_food,
	f2.value_year, 
	f2.avg_price_of_food,
	ROUND((f2.avg_price_of_food-AVG(f1.avg_price_of_food))/AVG(f1.avg_price_of_food)*100,2) AS percentual_difference
FROM t_david_wolf_project_sql_primary_final f1
JOIN (
SELECT 
	f1.value_year, 
	AVG(f1.avg_price_of_food) AS avg_price_of_food,
	f1.type_of_food
FROM t_david_wolf_project_sql_primary_final f1
GROUP BY f1.value_year, f1.type_of_food
) f2
	ON f1.value_year = f2.value_year-1
	AND f1.type_of_food = f2.type_of_food
GROUP BY f1.value_year, f1.type_of_food, f2.value_year, f2.type_of_food
	HAVING percentual_difference > 0
ORDER BY percentual_difference
LIMIT 1
;

-- 4. Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?
SELECT
	CONCAT(f1.payroll_year,'/',f2.payroll_year) AS payroll_year,
	-- f1.payroll_year,
	-- AVG(f1.avg_value) AS avg_value_payroll,
	-- AVG(f1.avg_price_of_food) AS 'avg_price_of_food',
	-- f2.payroll_year,
	-- f2.avg_value,
	-- f3.avg_price_of_food2,
	-- f2.avg_value-AVG(f1.avg_value) AS 'difference_payroll',
	-- ROUND(f3.avg_price_of_food2-AVG(f1.avg_price_of_food),2) AS difference_price_of_food,
	ROUND((f2.avg_value-AVG(f1.avg_value))/AVG(f1.avg_value)*100,2) AS percentual_difference_payroll,
	ROUND((AVG(f3.avg_price_of_food2)-AVG(f1.avg_price_of_food))/AVG(f1.avg_price_of_food)*100,2) AS percentual_difference_price_of_food,
	ROUND((AVG(f3.avg_price_of_food2)-AVG(f1.avg_price_of_food))/AVG(f1.avg_price_of_food)*100-((f2.avg_value-AVG(f1.avg_value))/AVG(f1.avg_value)*100),2) AS percentual_difference
FROM t_david_wolf_project_sql_primary_final f1
JOIN (
SELECT 
	f1.payroll_year,
	AVG(f1.avg_value) AS avg_value
FROM t_david_wolf_project_sql_primary_final f1
WHERE f1.value_type = 'Průměrná hrubá mzda na zaměstnance'
GROUP BY f1.payroll_year
) f2
	ON f1.payroll_year = f2.payroll_year-1
JOIN (
SELECT
	f1.payroll_year,
	f1.avg_price_of_food,
	f1.type_of_food,
	AVG(f1.avg_price_of_food) AS avg_price_of_food2
FROM t_david_wolf_project_sql_primary_final f1 
GROUP BY f1.payroll_year 
) f3
	ON f1.payroll_year = f3.payroll_year-1
WHERE f1.value_type = 'Průměrná hrubá mzda na zaměstnance'
GROUP BY f1.payroll_year
ORDER BY percentual_difference DESC
;

-- 5. Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, 
-- projeví se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?
SELECT 
	-- g1.country, 
	CONCAT(g1.YEAR,'/',g2.YEAR) AS year,
	-- g1.GDP, 
	-- g2.YEAR, 
	-- g2.GDP,
	ROUND((g2.GDP-g1.GDP)/g1.GDP*100,3) AS percentual_difference_GDP,
	-- f3.value_year,
	-- f3.avg_price_of_food,
	-- f3.value_year1,
	-- f3.avg_price_of_food1,
	ROUND((f3.avg_price_of_food1-f3.avg_price_of_food)/f3.avg_price_of_food*100,2) AS percentual_difference_food,
	-- p3.payroll_year,
	-- p3.avg_value,
	-- p3.payroll_year1,
	-- p3.avg_value1,
	ROUND((p3.avg_value1-p3.avg_value)/p3.avg_value*100,2) AS percentual_difference_payroll
FROM t_david_wolf_project_sql_secondary_final g1
JOIN (
	SELECT 
		g1.YEAR,
		g1.GDP
	FROM t_david_wolf_project_sql_secondary_final g1
	WHERE g1.country = 'Czech republic'
) g2
ON g1.YEAR = g2.YEAR-1
JOIN (
	SELECT 
		f1.value_year, 
		AVG(f1.avg_price_of_food) AS avg_price_of_food, 
		f2.value_year1, 
		f2.avg_price_of_food1 
	FROM t_david_wolf_project_sql_primary_final f1
	JOIN (
		SELECT 
			f1.value_year AS value_year1,
			AVG(f1.avg_price_of_food) AS avg_price_of_food1
		FROM t_david_wolf_project_sql_primary_final f1
		GROUP BY f1.value_year 
	) f2
	ON f1.value_year = f2.value_year1-1
	GROUP BY f1.value_year
) f3
ON g1.YEAR = f3.value_year
JOIN (
	SELECT 
		p2.payroll_year1,
		p2.avg_value1,
		p1.payroll_year,
		AVG(p1.avg_value) AS avg_value
	FROM t_david_wolf_project_sql_primary_final p1
	JOIN (
		SELECT
			p1.payroll_year AS payroll_year1,
			AVG(p1.avg_value) AS avg_value1
		FROM t_david_wolf_project_sql_primary_final p1
		WHERE p1.value_type = 'Průměrná hrubá mzda na zaměstnance'
		GROUP BY p1.payroll_year
	) p2
ON p1.payroll_year = p2.payroll_year1-1
WHERE p1.value_type = 'Průměrná hrubá mzda na zaměstnance'
GROUP BY p1.payroll_year
) p3
ON g1.YEAR = p3.payroll_year
WHERE g1.country = 'Czech republic'
ORDER BY YEAR
;

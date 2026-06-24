/*
================================================================================
PROYECTO: People Analytics - Diagnóstico de Burnout y Retención de Talento
AUTOR: Adrián Poet | Data Analyst & BI Specialist
FECHA: Junio 2026
DESCRIPCIÓN: Script completo para la creación de la base de datos, 
             transformación cualitativa de métricas (Data Engineering) 
             y consultas analíticas avanzadas de recursos humanos.
================================================================================
*/

-- =============================================================================
-- FASE 1: INSTANCIACIÓN DE BASE DE DATOS Y CARGA DE DATOS ORIGINALES
-- =============================================================================

-- Creación de la base de datos contenedora
CREATE DATABASE Recursos_Humanos;
USE Recursos_Humanos;

-- Creación de la tabla maestra con el staff inicial de la organización
CREATE TABLE analisis_empleados (
    id_empleado INT PRIMARY KEY,
    edad INT,
    genero VARCHAR(20),
    departamento VARCHAR(50),
    sueldo_mensual DECIMAL(10,2),
    distancia_oficina_km INT,
    años_experiencia INT,
    nivel_satisfaccion INT,
    horas_extras_mes INT,
    riesgo_renuncia INT  -- Columna reservada para futuras actualizaciones numéricas
);

-- Inserción del Dataset Original 
INSERT INTO analisis_empleados 
    (id_empleado, edad, genero, departamento, sueldo_mensual, distancia_oficina_km, años_experiencia, nivel_satisfaccion, horas_extras_mes)
VALUES
    (1001, 28, 'Masculino', 'IT', 115000.00, 12, 4, 2, 32),
    (1002, 45, 'Femenino', 'Ventas', 138000.00, 45, 18, 4, 10),
    (1003, 31, 'No Binario', 'Finanzas', 92000.00, 5, 8, 5, 0),
    (1004, 24, 'Femenino', 'Marketing', 45000.00, 28, 2, 1, 28),
    (1005, 52, 'Masculino', 'IT', 142000.00, 15, 25, 3, 15),
    (1006, 39, 'Femenino', 'RRHH', 88000.00, 2, 12, 4, 5),
    (1007, 27, 'Masculino', 'Ventas', 62000.00, 38, 5, 2, 35),
    (1008, 48, 'No Binario', 'Finanzas', 125000.00, 10, 20, 5, 0),
    (1009, 35, 'Femenino', 'IT', 105000.00, 22, 10, 3, 20),
    (1010, 42, 'Masculino', 'Marketing', 98000.00, 18, 15, 2, 12);

- =============================================================================
-- FASE 2: INGENIERÍA Y LOGICA DE NEGOCIO ("HUMANIZACIÓN DE DATOS")
-- =============================================================================

/* 
   Paso 1: Creación de Vista Intermedia.
   Se transforman los rangos numéricos cuantitativos en categorías cualitativas
   de negocio para facilitar la lectura cruzada y el análisis corporativo.
*/
CREATE VIEW vista_tabla_humanizada AS
SELECT 
    id_empleado,
    departamento,
    sueldo_mensual,
    distancia_oficina_km,
    nivel_satisfaccion,
    horas_extras_mes,
    años_experiencia,
    -- Segmentación Salarial interna
    CASE 
        WHEN sueldo_mensual >= 100000 THEN 'Alto'
        WHEN sueldo_mensual >= 80000 THEN 'Medio'
        ELSE 'Bajo'
    END AS clasificacion_salario,
    -- Segmentación de Desgaste por Traslado (Distancia)
    CASE 
        WHEN distancia_oficina_km >= 25 THEN 'Larga'
        WHEN distancia_oficina_km >= 15 THEN 'Media'
        ELSE 'Corta'
    END AS clasificacion_distancia,
    -- Clasificación de Seniority / Antigüedad laboral
    CASE 
        WHEN años_experiencia >= 12 THEN 'Alta'
        WHEN años_experiencia >= 8 THEN 'Media'
        ELSE 'Baja'
    END AS nivel_antiguedad,
    -- Mapeo cualitativo del clima/satisfacción percibida
    CASE 
        WHEN nivel_satisfaccion >= 4 THEN 'Alta'
        WHEN nivel_satisfaccion = 3 THEN 'Media'
        ELSE 'Baja'
    END AS clasificacion_satisfaccion,
    -- Categorización de la Carga Operativa (Horas Extras)
    CASE 
        WHEN horas_extras_mes >= 25 THEN 'Carga Alta'
        WHEN horas_extras_mes >= 11 THEN 'Carga Media'
        ELSE 'Carga Baja'
    END AS carga_horas_extras
FROM analisis_empleados;


/* 
   Paso 2: Creación de Vista Final Maestra (Matriz de Riesgo).
   Se diseña un algoritmo lógico combinatorio para encasillar en riesgo 'ALTA' 
   a aquellos empleados que sufren de Burnout Simultáneo (Baja Satisfacción + 
   Carga Alta de Hs Extras + Salario Bajo).
*/
CREATE VIEW vista_tabla_completa AS
SELECT 
    *,
    CASE 
        WHEN carga_horas_extras = 'Carga Alta' 
             AND clasificacion_satisfaccion = 'Baja' 
             AND clasificacion_salario = 'Bajo' THEN 'ALTA'
        ELSE 'BAJA'
    END AS riesgo_renuncia
FROM vista_tabla_humanizada;


-- =============================================================================
-- FASE 3: CONSULTAS DE EXTRACCIÓN DE INSIGHTS (BUSINESS INTELLIGENCE)
-- =============================================================================

/* 
   Consulta A: KPI de Rotación General
   Mide la distribución y el porcentaje de impacto del riesgo de fuga sobre el total de la plantilla.
*/
WITH clasificacion_cantidad AS (
    SELECT
        riesgo_renuncia AS Riesgo_renuncia,
        COUNT(*) AS Personas
    FROM vista_tabla_completa
    GROUP BY riesgo_renuncia
)
SELECT
    Riesgo_renuncia,
    Personas,
    ROUND(Personas / SUM(CAST(Personas AS FLOAT)) OVER () * 100, 2) AS Porcentaje
FROM clasificacion_cantidad;


/* 
   Consulta B: Radiografía Estratégica por Departamento
   Analiza promedios salariales, porcentaje de participación en la masa salarial global,
   volumen total de sobrecarga horaria, traslados y el promedio resultante del clima laboral.
*/
WITH calculos AS (
    SELECT 
        departamento,
        ROUND(AVG(CAST(sueldo_mensual AS FLOAT)), 2) AS Promedio_Sueldo,
        SUM(sueldo_mensual) AS Salario_Total,
        SUM(horas_extras_mes) AS Total_Hs_Extras,
        SUM(distancia_oficina_km) AS Total_Distancia, 
        ROUND(AVG(CAST(nivel_satisfaccion AS FLOAT)), 2) AS Promedio_Satisfaccion
    FROM vista_tabla_completa 
    GROUP BY departamento
)
SELECT 
    departamento,
    Promedio_Sueldo,
    ROUND(Salario_Total / SUM(CAST(Salario_Total AS FLOAT)) OVER () * 100, 2) AS [% Total Salario],
    Total_Hs_Extras,
    Total_Distancia,
    Promedio_Satisfaccion
FROM calculos
ORDER BY Promedio_Sueldo DESC;


/* 
   Consulta C: Aislamiento Nominal de Empleados de Riesgo Alto
   Generación de una vista exclusiva para el departamento de Recursos Humanos
   con el fin de aplicar planes de contingencia salarial y/o retención inmediata.
*/
CREATE VIEW empleados_riesgo_fuga AS
SELECT * 
FROM vista_tabla_completa
WHERE riesgo_renuncia = 'ALTA';

-- Visualización de los empleados críticos aislados
SELECT * FROM empleados_riesgo_fuga;


/* 
   Consulta D: Análisis de Buenas Prácticas (Patrón de Satisfacción Alta)
   Investigación inversa para detectar qué variables garantizan la felicidad laboral.
   Evidencia: Correlación directa entre Satisfacción Alta y Horas Extras en 'Carga Baja'.
*/
SELECT *
FROM vista_tabla_completa
WHERE clasificacion_satisfaccion = 'Alta';

-- ============================================================
--  JOUR 10 / 10 DAYS OF SQL — Setup : Vues & Triggers
--  Schéma RH : employees · departments · salaires · audit_log
-- ============================================================

DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS salaires;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS departments;

-- ── Table DEPARTMENTS ────────────────────────────────────────
CREATE TABLE departments (
    id      INTEGER PRIMARY KEY,
    nom     TEXT NOT NULL,
    budget  INTEGER NOT NULL,
    ville   TEXT NOT NULL
);

INSERT INTO departments VALUES
(1, 'Ventes',    280000, 'Paris'),
(2, 'IT',        420000, 'Paris'),
(3, 'Marketing', 190000, 'Lyon'),
(4, 'RH',        110000, 'Lyon'),
(5, 'Finance',   250000, 'Bordeaux');

-- ── Table EMPLOYEES ──────────────────────────────────────────
CREATE TABLE employees (
    id            INTEGER PRIMARY KEY,
    prenom        TEXT NOT NULL,
    nom           TEXT NOT NULL,
    department_id INTEGER NOT NULL,
    poste         TEXT NOT NULL,
    date_embauche DATE NOT NULL,
    actif         INTEGER NOT NULL DEFAULT 1,  -- 1=actif, 0=parti
    FOREIGN KEY (department_id) REFERENCES departments(id)
);

INSERT INTO employees VALUES
(1,  'Alice',   'Martin',   1, 'Manager Ventes',      '2019-03-12', 1),
(2,  'Karim',   'Benali',   1, 'Commercial',          '2021-06-01', 1),
(3,  'Lucie',   'Dubois',   3, 'Chargée Marketing',   '2022-01-15', 1),
(4,  'Thomas',  'Roux',     2, 'Développeur',         '2020-09-23', 1),
(5,  'Nadia',   'Khelifi',  1, 'Commerciale',         '2021-11-08', 1),
(6,  'Julien',  'Petit',    2, 'Lead Dev',            '2018-02-14', 1),
(7,  'Sophie',  'Moreau',   4, 'Responsable RH',      '2017-05-19', 1),
(8,  'Pierre',  'Lambert',  5, 'Analyste Financier',  '2020-04-02', 1),
(9,  'Emma',    'Garcia',   3, 'Directrice Marketing','2016-08-30', 1),
(10, 'Maxime',  'David',    2, 'Développeur',         '2022-03-21', 1),
(11, 'Chloé',   'Bertrand', 1, 'Commerciale',         '2023-01-10', 1),
(12, 'Hugo',    'Fontaine', 5, 'Directeur Financier', '2015-11-03', 1),
(13, 'Léa',     'Girard',   4, 'Chargée RH',          '2022-07-18', 1),
(14, 'Antoine', 'Mercier',  2, 'Dev Junior',          '2023-09-05', 0),  -- parti
(15, 'Camille', 'Lefebvre', 3, 'Chargée Marketing',   '2021-04-27', 1);

-- ── Table SALAIRES (historique) ──────────────────────────────
CREATE TABLE salaires (
    id            INTEGER PRIMARY KEY,
    employee_id   INTEGER NOT NULL,
    montant       INTEGER NOT NULL,
    date_effet    DATE NOT NULL,
    FOREIGN KEY (employee_id) REFERENCES employees(id)
);

INSERT INTO salaires VALUES
(1,  1,  52000, '2019-03-12'),
(2,  1,  55000, '2021-01-01'),
(3,  1,  58000, '2023-01-01'),
(4,  2,  38000, '2021-06-01'),
(5,  2,  42000, '2023-06-01'),
(6,  3,  36000, '2022-01-15'),
(7,  3,  39000, '2024-01-01'),
(8,  4,  42000, '2020-09-23'),
(9,  4,  46000, '2022-09-23'),
(10, 5,  40000, '2021-11-08'),
(11, 5,  43500, '2023-11-08'),
(12, 6,  55000, '2018-02-14'),
(13, 6,  62000, '2021-02-14'),
(14, 7,  48000, '2017-05-19'),
(15, 7,  55000, '2022-05-19'),
(16, 8,  44000, '2020-04-02'),
(17, 8,  48000, '2023-04-02'),
(18, 9,  60000, '2016-08-30'),
(19, 9,  67000, '2020-08-30'),
(20, 10, 40000, '2022-03-21'),
(21, 10, 44000, '2024-03-21'),
(22, 11, 38000, '2023-01-10'),
(23, 11, 41000, '2024-01-10'),
(24, 12, 68000, '2015-11-03'),
(25, 12, 75000, '2020-11-03'),
(26, 13, 36000, '2022-07-18'),
(27, 13, 38000, '2024-07-18'),
(28, 14, 33000, '2023-09-05'),
(29, 15, 37000, '2021-04-27'),
(30, 15, 40000, '2023-04-27');

-- ── Table AUDIT_LOG (remplie automatiquement par triggers) ───
CREATE TABLE audit_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name  TEXT NOT NULL,
    operation   TEXT NOT NULL,      -- INSERT / UPDATE / DELETE
    row_id      INTEGER,
    detail      TEXT,
    horodatage  DATETIME DEFAULT (datetime('now'))
);

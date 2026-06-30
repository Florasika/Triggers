-- ============================================================
--  JOUR 10 / 10 DAYS OF SQL — Vues & Triggers
--  Concepts : CREATE VIEW · DROP VIEW · CREATE TRIGGER
--             AFTER INSERT/UPDATE/DELETE · NEW / OLD
-- ============================================================

-- ════════════════════════════════════════════════════════════
--  PARTIE 1 — VUES (CREATE VIEW)
-- ════════════════════════════════════════════════════════════

-- ── 1. CREATE VIEW simple : fiche employé complète ───────────
-- Une vue = une requête nommée et réutilisable
CREATE VIEW IF NOT EXISTS v_employes_actifs AS
SELECT
    e.id,
    e.prenom || ' ' || e.nom AS nom_complet,
    d.nom AS departement,
    d.ville,
    e.poste,
    e.date_embauche,
    -- Ancienneté en années (calculée à chaque appel)
    CAST(
        (julianday('now') - julianday(e.date_embauche)) / 365.25
    AS INTEGER) AS anciennete_annees
FROM employees e
INNER JOIN departments d ON e.department_id = d.id
WHERE e.actif = 1;

-- Utilisation : exactement comme une table normale
SELECT * FROM v_employes_actifs ORDER BY departement, nom_complet;


-- ── 2. Vue avec salaire actuel (sous-requête dans la vue) ────
CREATE VIEW IF NOT EXISTS v_salaires_actuels AS
SELECT
    e.id,
    e.prenom || ' ' || e.nom AS nom_complet,
    d.nom AS departement,
    s.montant AS salaire_actuel,
    s.date_effet AS date_derniere_augmentation
FROM employees e
INNER JOIN departments d ON e.department_id = d.id
-- Sous-requête corrélée : salaire le plus récent de chaque employé
INNER JOIN salaires s ON s.id = (
    SELECT id FROM salaires
    WHERE employee_id = e.id
    ORDER BY date_effet DESC
    LIMIT 1
)
WHERE e.actif = 1;

-- Vérification
SELECT * FROM v_salaires_actuels ORDER BY salaire_actuel DESC;


-- ── 3. Vue analytique : stats RH par département ─────────────
CREATE VIEW IF NOT EXISTS v_stats_departements AS
SELECT
    d.nom AS departement,
    d.budget,
    COUNT(e.id) AS nb_employes,
    ROUND(AVG(s.montant), 0) AS salaire_moyen,
    MIN(s.montant) AS salaire_min,
    MAX(s.montant) AS salaire_max,
    SUM(s.montant) AS masse_salariale,
    -- Ratio masse salariale / budget département
    ROUND(100.0 * SUM(s.montant) / d.budget, 1) AS pct_budget_utilise
FROM departments d
LEFT JOIN employees e ON e.department_id = d.id AND e.actif = 1
LEFT JOIN salaires s ON s.id = (
    SELECT id FROM salaires
    WHERE employee_id = e.id
    ORDER BY date_effet DESC LIMIT 1
)
GROUP BY d.id, d.nom, d.budget;

SELECT * FROM v_stats_departements ORDER BY masse_salariale DESC;


-- ── 4. Utiliser une vue dans une requête ─────────────────────
-- Employés gagnant plus que la moyenne de leur département
SELECT
    sa.nom_complet,
    sa.departement,
    sa.salaire_actuel,
    ROUND(sd.salaire_moyen, 0) AS moyenne_dept
FROM v_salaires_actuels sa
INNER JOIN v_stats_departements sd ON sa.departement = sd.departement
WHERE sa.salaire_actuel > sd.salaire_moyen
ORDER BY sa.departement, sa.salaire_actuel DESC;


-- ── 5. Voir toutes les vues existantes ───────────────────────
SELECT name, sql
FROM sqlite_master
WHERE type = 'view'
ORDER BY name;


-- ── 6. Supprimer une vue ─────────────────────────────────────
-- DROP VIEW IF EXISTS v_ancienne_vue;
-- (Commenté pour ne pas casser les exemples suivants)


-- ════════════════════════════════════════════════════════════
--  PARTIE 2 — TRIGGERS
-- ════════════════════════════════════════════════════════════

-- ── 7. TRIGGER AFTER INSERT : log chaque nouvel employé ──────
CREATE TRIGGER IF NOT EXISTS trg_employe_insert
AFTER INSERT ON employees
BEGIN
    INSERT INTO audit_log (table_name, operation, row_id, detail)
    VALUES (
        'employees',
        'INSERT',
        NEW.id,
        'Nouvel employé : ' || NEW.prenom || ' ' || NEW.nom ||
        ' — Département ID: ' || NEW.department_id
    );
END;

-- Test du trigger
INSERT INTO employees (id, prenom, nom, department_id, poste, date_embauche)
VALUES (16, 'Yasmine', 'Amrani', 2, 'Développeuse', '2024-06-01');

-- Vérifier que le log a été créé automatiquement
SELECT * FROM audit_log;


-- ── 8. TRIGGER AFTER UPDATE : tracer les changements de salaire
CREATE TRIGGER IF NOT EXISTS trg_salaire_update
AFTER INSERT ON salaires
BEGIN
    INSERT INTO audit_log (table_name, operation, row_id, detail)
    VALUES (
        'salaires',
        'INSERT',
        NEW.employee_id,
        'Nouveau salaire : ' || NEW.montant || '€' ||
        ' (effet : ' || NEW.date_effet || ')'
    );
END;

-- Test : ajouter une augmentation pour Yasmine
INSERT INTO salaires (employee_id, montant, date_effet)
VALUES (16, 46000, '2024-06-01');

SELECT * FROM audit_log ORDER BY id;


-- ── 9. TRIGGER AFTER DELETE : archiver avant suppression ─────
CREATE TRIGGER IF NOT EXISTS trg_employe_depart
AFTER UPDATE OF actif ON employees
WHEN NEW.actif = 0
BEGIN
    INSERT INTO audit_log (table_name, operation, row_id, detail)
    VALUES (
        'employees',
        'DEPART',
        NEW.id,
        'Départ employé : ' || NEW.prenom || ' ' || NEW.nom ||
        ' — Date : ' || date('now')
    );
END;

-- Test : marquer un départ
UPDATE employees SET actif = 0 WHERE id = 16;

SELECT * FROM audit_log ORDER BY id;


-- ── 10. TRIGGER de validation : empêcher un salaire < SMIC ───
CREATE TRIGGER IF NOT EXISTS trg_salaire_minimum
BEFORE INSERT ON salaires
WHEN NEW.montant < 21203  -- SMIC annuel 2024
BEGIN
    SELECT RAISE(ABORT, 'Erreur : salaire inférieur au SMIC annuel (21203€)');
END;

-- Test : essayer d'insérer un salaire trop bas (doit échouer)
-- INSERT INTO salaires (employee_id, montant, date_effet)
-- VALUES (1, 15000, '2024-01-01');
-- → Erreur : Erreur : salaire inférieur au SMIC annuel (21203€)

-- Test valide : salaire correct
INSERT INTO salaires (employee_id, montant, date_effet)
VALUES (11, 43000, '2024-10-01');
SELECT 'Test salaire OK' AS resultat;


-- ── 11. Voir tous les triggers existants ─────────────────────
SELECT name, tbl_name, sql
FROM sqlite_master
WHERE type = 'trigger'
ORDER BY name;


-- ── 12. REQUÊTE FINALE — Tableau de bord RH complet ─────────
SELECT
    sa.nom_complet,
    sa.departement,
    ea.poste,
    sa.salaire_actuel,
    ea.anciennete_annees || ' an(s)' AS anciennete,
    CASE
        WHEN sa.salaire_actuel > sd.salaire_moyen THEN '↑ Dessus moyenne'
        WHEN sa.salaire_actuel = sd.salaire_moyen THEN '= Dans la moyenne'
        ELSE '↓ Sous la moyenne'
    END AS position_salaire
FROM v_salaires_actuels sa
INNER JOIN v_employes_actifs ea ON sa.id = ea.id
INNER JOIN v_stats_departements sd ON sa.departement = sd.departement
ORDER BY sa.departement, sa.salaire_actuel DESC;

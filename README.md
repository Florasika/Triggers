# 🏗️ Jour 10 / 10 — SQL : Vues & Triggers

> **Série : 10 Days of SQL** · Jour 10/10 — DERNIER JOUR 🎉  
> Concepts : CREATE VIEW · DROP VIEW · CREATE TRIGGER · NEW / OLD · RAISE(ABORT)

---

## 📁 Structure du projet

```
day-10-views-triggers/
│
├── 01_setup.sql            ← Schéma RH complet (departments, employees, salaires, audit_log)
├── 02_views_triggers.sql   ← 12 requêtes — 3 vues + 4 triggers
├── rh.db                    ← Base SQLite prête à l'emploi
└── README.md
```

---

## 🚀 Installation & Lancement

```bash
# Cloner le repo
git clone https://github.com/ton-pseudo/10-days-sql.git
cd 10-days-sql/day-10-views-triggers

# Ouvrir la base directement (déjà créée)
sqlite3 rh.db

# OU recréer la base depuis zéro
sqlite3 rh.db < 01_setup.sql

# Exécuter toutes les requêtes
sqlite3 rh.db < 02_views_triggers.sql
```

---

## 📊 Le schéma — 4 tables

```
departments (5 lignes)     employees (15 lignes)
├── id, nom, budget, ville  ├── id, prenom, nom, department_id (FK)
                            ├── poste, date_embauche
                            └── actif (1=actif, 0=parti)

salaires (30 lignes)        audit_log (remplie par les triggers)
├── id, employee_id (FK)    ├── id (AUTOINCREMENT)
├── montant                 ├── table_name, operation, row_id
└── date_effet              ├── detail
                            └── horodatage (DEFAULT datetime('now'))
```

---

## 🔑 PARTIE 1 — VUES

### Qu'est-ce qu'une vue ?

Une vue est une **requête nommée et sauvegardée** dans la base. Elle se comporte exactement comme une table — on peut la lire avec `SELECT`, la filtrer avec `WHERE`, la joindre avec `JOIN`.

**Différence fondamentale** : une vue ne stocke pas de données. Elle ré-exécute la requête sous-jacente à chaque appel — ce qui signifie que les données sont toujours à jour.

---

### 1. CREATE VIEW simple

```sql
CREATE VIEW IF NOT EXISTS v_employes_actifs AS
SELECT
    e.id,
    e.prenom || ' ' || e.nom AS nom_complet,
    d.nom AS departement,
    e.poste,
    CAST((julianday('now') - julianday(e.date_embauche)) / 365.25 AS INTEGER) AS anciennete_annees
FROM employees e
INNER JOIN departments d ON e.department_id = d.id
WHERE e.actif = 1;

-- Utilisation : comme une table normale
SELECT * FROM v_employes_actifs WHERE departement = 'IT';
```

---

### 2. Vue avec salaire actuel (sous-requête corrélée)

```sql
CREATE VIEW IF NOT EXISTS v_salaires_actuels AS
SELECT
    e.prenom || ' ' || e.nom AS nom_complet,
    d.nom AS departement,
    s.montant AS salaire_actuel
FROM employees e
INNER JOIN departments d ON e.department_id = d.id
INNER JOIN salaires s ON s.id = (
    SELECT id FROM salaires
    WHERE employee_id = e.id
    ORDER BY date_effet DESC
    LIMIT 1          -- salaire le plus récent uniquement
)
WHERE e.actif = 1;
```

---

### 3. Vue analytique — stats par département

```sql
CREATE VIEW IF NOT EXISTS v_stats_departements AS
SELECT
    d.nom AS departement,
    d.budget,
    COUNT(e.id) AS nb_employes,
    ROUND(AVG(s.montant), 0) AS salaire_moyen,
    SUM(s.montant) AS masse_salariale,
    ROUND(100.0 * SUM(s.montant) / d.budget, 1) AS pct_budget_utilise
FROM departments d
LEFT JOIN employees e ON e.department_id = d.id AND e.actif = 1
LEFT JOIN salaires s ON s.id = (
    SELECT id FROM salaires WHERE employee_id = e.id
    ORDER BY date_effet DESC LIMIT 1
)
GROUP BY d.id, d.nom, d.budget;
```

### Utiliser deux vues ensemble

```sql
-- Employés gagnant plus que la moyenne de leur département
SELECT sa.nom_complet, sa.salaire_actuel, sd.salaire_moyen
FROM v_salaires_actuels sa
INNER JOIN v_stats_departements sd ON sa.departement = sd.departement
WHERE sa.salaire_actuel > sd.salaire_moyen;
```

### Gérer les vues

```sql
-- Voir toutes les vues
SELECT name FROM sqlite_master WHERE type = 'view';

-- Supprimer une vue
DROP VIEW IF EXISTS v_ancienne_vue;
```

---

## 🔑 PARTIE 2 — TRIGGERS

### Qu'est-ce qu'un trigger ?

Un trigger est du code SQL qui s'exécute **automatiquement** quand une opération (`INSERT`, `UPDATE`, `DELETE`) se produit sur une table. Aucune intervention manuelle nécessaire.

Il y a accès à deux pseudo-tables spéciales :
- `NEW` → la nouvelle ligne (disponible dans INSERT et UPDATE)
- `OLD` → l'ancienne ligne (disponible dans UPDATE et DELETE)

---

### 4. TRIGGER AFTER INSERT — log automatique

```sql
CREATE TRIGGER IF NOT EXISTS trg_employe_insert
AFTER INSERT ON employees
BEGIN
    INSERT INTO audit_log (table_name, operation, row_id, detail)
    VALUES (
        'employees', 'INSERT', NEW.id,
        'Nouvel employé : ' || NEW.prenom || ' ' || NEW.nom
    );
END;
```
Chaque `INSERT INTO employees` crée automatiquement une ligne dans `audit_log` — sans que l'application ait à le faire.

---

### 5. TRIGGER AFTER UPDATE — tracer les changements

```sql
CREATE TRIGGER IF NOT EXISTS trg_employe_depart
AFTER UPDATE OF actif ON employees
WHEN NEW.actif = 0           -- s'active uniquement si actif passe à 0
BEGIN
    INSERT INTO audit_log (table_name, operation, row_id, detail)
    VALUES (
        'employees', 'DEPART', NEW.id,
        'Départ : ' || NEW.prenom || ' ' || NEW.nom || ' — ' || date('now')
    );
END;
```
`AFTER UPDATE OF colonne` — le trigger ne se déclenche que si cette colonne est modifiée.  
`WHEN condition` — filtre supplémentaire pour ne s'activer que dans certains cas.

---

### 6. TRIGGER BEFORE INSERT — validation des données

```sql
CREATE TRIGGER IF NOT EXISTS trg_salaire_minimum
BEFORE INSERT ON salaires
WHEN NEW.montant < 21203        -- SMIC annuel 2024
BEGIN
    SELECT RAISE(ABORT, 'Erreur : salaire inférieur au SMIC annuel (21203€)');
END;
```
`BEFORE` s'exécute avant l'opération — si `RAISE(ABORT)` est appelé, l'INSERT est annulé et un message d'erreur est retourné.

---

### 7. Voir et supprimer les triggers

```sql
-- Voir tous les triggers
SELECT name, tbl_name FROM sqlite_master WHERE type = 'trigger';

-- Supprimer un trigger
DROP TRIGGER IF EXISTS trg_employe_insert;
```

---

## 🧠 Vue vs Trigger — quand utiliser quoi ?

| Outil | Quand l'utiliser |
|---|---|
| **Vue** | Simplifier une requête complexe réutilisée souvent |
| **Vue** | Exposer une partie de la base (sécurité, lisibilité) |
| **Vue** | Centraliser la logique métier (calcul ancienneté, salaire actuel) |
| **Trigger AFTER** | Journal d'audit automatique |
| **Trigger AFTER** | Mise à jour automatique d'une table résumé |
| **Trigger BEFORE** | Valider des données avant insertion |
| **Trigger BEFORE** | Empêcher une opération incorrecte avec RAISE(ABORT) |

---

## 🎓 Bilan de la série — 10 Days of SQL

| Jour | Sujet | Concepts clés |
|------|-------|---------------|
| 1 | SELECT basiques | SELECT, WHERE, ORDER BY, LIMIT |
| 2 | Jointures | INNER JOIN, LEFT JOIN, FULL OUTER |
| 3 | Agrégations | GROUP BY, HAVING, COUNT, SUM, AVG |
| 4 | Sous-requêtes & CTE | WITH AS, EXISTS, subquery corrélée |
| 5 | Window Functions | ROW_NUMBER, RANK, LAG, LEAD |
| 6 | CASE WHEN | Pivot manuel, tri custom |
| 7 | Dates | strftime, julianday, date() |
| 8 | Texte | TRIM, SUBSTR, REPLACE, COALESCE |
| 9 | Index | EXPLAIN, CREATE INDEX, index composé |
| **10** | **Vues & Triggers** | **CREATE VIEW, CREATE TRIGGER** |
--- 

⭐ **Si ce projet t'aide, mets une étoile !**

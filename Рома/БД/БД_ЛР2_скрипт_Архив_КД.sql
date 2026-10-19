-- Физическая модель БД «Архив конструкторской документации»
-- (ЛР2, вариант 7), PostgreSQL
CREATE TABLE department (
    dept_code CHAR(3)      PRIMARY KEY CHECK (dept_code ~ '^[0-9]{3}$'),
    name      VARCHAR(100) NOT NULL UNIQUE
);
CREATE TABLE employee (
    employee_id INTEGER      PRIMARY KEY,          -- табельный номер
    full_name   VARCHAR(100) NOT NULL,
    position    VARCHAR(60)  NOT NULL,
    dept_code   CHAR(3)      NOT NULL REFERENCES department
);
CREATE TABLE product (
    product_id  SERIAL PRIMARY KEY,
    designation VARCHAR(20)  NOT NULL UNIQUE
                CHECK (designation ~ '^[А-Я]{4}\.[0-9]{6}\.[0-9]{3}$'),
    name        VARCHAR(150) NOT NULL,
    kind        VARCHAR(20)  NOT NULL
                CHECK (kind IN ('деталь', 'сборочная единица',
                                'комплекс', 'комплект')),
    dept_code   CHAR(3)      NOT NULL REFERENCES department -- разработчик
);
CREATE TABLE product_part (
    assembly_id INTEGER  NOT NULL REFERENCES product,
    part_id     INTEGER  NOT NULL REFERENCES product,
    quantity    SMALLINT NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (assembly_id, part_id),
    CHECK (assembly_id <> part_id)
);
CREATE TABLE document (
    document_id   SERIAL PRIMARY KEY,
    product_id    INTEGER     NOT NULL REFERENCES product,
    doc_code      VARCHAR(4)  NOT NULL
                  CHECK (doc_code IN ('ЧД', 'СП', 'СБ', 'ВО',
                                      'Э3', 'ПЭ3', 'ТУ', 'ПЗ')),
    sheet_format  VARCHAR(6)  NOT NULL,
    sheets        SMALLINT    NOT NULL CHECK (sheets > 0),
    litera        VARCHAR(3)  NOT NULL,
    received_date DATE        NOT NULL,
    UNIQUE (product_id, doc_code)
);
CREATE TABLE notice (
    notice_id   SERIAL PRIMARY KEY,
    notice_no   VARCHAR(20)  NOT NULL UNIQUE,
    notice_date DATE         NOT NULL,
    reason      VARCHAR(200) NOT NULL,
    dept_code   CHAR(3)      NOT NULL REFERENCES department
);
CREATE TABLE doc_change (
    document_id    INTEGER     NOT NULL REFERENCES document,
    change_no      SMALLINT    NOT NULL CHECK (change_no > 0),
    notice_id      INTEGER     NOT NULL REFERENCES notice,
    change_date    DATE        NOT NULL,
    changed_sheets VARCHAR(40) NOT NULL,
    PRIMARY KEY (document_id, change_no),
    UNIQUE (document_id, notice_id)
);
CREATE TABLE subscription (
    dept_code   CHAR(3)  NOT NULL REFERENCES department,
    document_id INTEGER  NOT NULL REFERENCES document,
    copies      SMALLINT NOT NULL CHECK (copies > 0),
    since_date  DATE     NOT NULL,
    PRIMARY KEY (dept_code, document_id)
);
CREATE TABLE sign_role (
    role_code VARCHAR(6)  PRIMARY KEY,
    name      VARCHAR(40) NOT NULL UNIQUE
);
CREATE TABLE signature (
    document_id INTEGER    NOT NULL REFERENCES document,
    role_code   VARCHAR(6) NOT NULL REFERENCES sign_role,
    employee_id INTEGER    NOT NULL REFERENCES employee,
    sign_date   DATE       NOT NULL,
    PRIMARY KEY (document_id, role_code)
);
CREATE INDEX ix_product_dept   ON product(dept_code);
CREATE INDEX ix_part_part      ON product_part(part_id);
CREATE INDEX ix_change_notice  ON doc_change(notice_id);
CREATE INDEX ix_signature_emp  ON signature(employee_id);
CREATE INDEX ix_subscr_doc     ON subscription(document_id);
 
-- Правила, которые не выражаются внешними ключами (замыкание циклов)
CREATE FUNCTION check_part() RETURNS trigger AS $$
BEGIN
    IF EXISTS (WITH RECURSIVE up(id) AS (
                   SELECT NEW.assembly_id
                   UNION
                   SELECT pp.assembly_id FROM product_part pp
                     JOIN up ON pp.part_id = up.id)
               SELECT 1 FROM up WHERE id = NEW.part_id) THEN
        RAISE EXCEPTION 'Цикл в составе: изделие входит само в себя';
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_part BEFORE INSERT OR UPDATE ON product_part
    FOR EACH ROW EXECUTE FUNCTION check_part();

CREATE FUNCTION check_change() RETURNS trigger AS $$
DECLARE n notice; p product;
BEGIN
    SELECT * INTO n FROM notice WHERE notice_id = NEW.notice_id;
    SELECT pr.* INTO p FROM product pr
      JOIN document d ON d.product_id = pr.product_id
     WHERE d.document_id = NEW.document_id;
    IF n.dept_code <> p.dept_code THEN
        RAISE EXCEPTION 'Извещение выпущено не разработчиком изделия';
    END IF;
    IF NEW.change_date < n.notice_date THEN
        RAISE EXCEPTION 'Изменение внесено раньше даты извещения';
    END IF;
    IF NEW.change_no <> 1 + COALESCE((SELECT MAX(change_no)
            FROM doc_change WHERE document_id = NEW.document_id
             AND change_no <> NEW.change_no), 0) THEN
        RAISE EXCEPTION 'Номер изменения должен быть следующим';
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_change BEFORE INSERT OR UPDATE ON doc_change
    FOR EACH ROW EXECUTE FUNCTION check_change();

CREATE FUNCTION check_signature() RETURNS trigger AS $$
BEGIN
    IF NEW.role_code IN ('РАЗР', 'ПРОВ') AND EXISTS (
            SELECT 1 FROM signature
             WHERE document_id = NEW.document_id
               AND employee_id = NEW.employee_id
               AND role_code IN ('РАЗР', 'ПРОВ')
               AND role_code <> NEW.role_code) THEN
        RAISE EXCEPTION 'Разработчик не может проверять свой документ';
    END IF;
    RETURN NEW;
END $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_signature BEFORE INSERT OR UPDATE ON signature
    FOR EACH ROW EXECUTE FUNCTION check_signature();

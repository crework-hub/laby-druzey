-- Пример данных из таблицы 4 ЛР1 и проверка ограничений (ЛР2, вариант 7)
INSERT INTO department VALUES
 ('090', 'Технический архив'),
 ('220', 'Конструкторское бюро электронных устройств (КБ-2)'),
 ('230', 'Конструкторское бюро корпусов и механики (КБ-3)'),
 ('310', 'Сборочный цех № 3');
INSERT INTO employee VALUES
 (1002, 'Жук А. П.',       'начальник КБ-2',           '220'),
 (1043, 'Кравец О. Н.',    'инженер-конструктор',      '220'),
 (1051, 'Белова Т. Ю.',    'ведущий инженер-конструктор', '220'),
 (2007, 'Савицкая Л. М.',  'инженер по нормоконтролю', '090');
INSERT INTO product (designation, name, kind, dept_code) VALUES
 ('НПГУ.436234.012', 'Блок питания БП-12', 'сборочная единица', '220'),
 ('НПГУ.741124.003', 'Корпус',             'деталь',            '220'),
 ('НПГУ.758725.001', 'Плата печатная',     'деталь',            '220');
INSERT INTO product_part VALUES (1, 2, 1), (1, 3, 1);
INSERT INTO document (product_id, doc_code, sheet_format, sheets, litera, received_date) VALUES
 (1, 'СБ', 'A2', 1, 'О1', '2026-03-12'),
 (1, 'Э3', 'A3', 1, 'О1', '2026-03-12'),
 (1, 'СП', 'A4', 2, 'О1', '2026-03-12'),
 (2, 'ЧД', 'A3', 1, 'О1', '2026-03-12'),
 (3, 'ЧД', 'A2', 1, 'О1', '2026-03-12');
INSERT INTO notice (notice_no, notice_date, reason, dept_code) VALUES
 ('НПГУ.012-26', '2026-09-14', 'Замена конденсатора C4 на конденсатор большей ёмкости', '220'),
 ('НПГУ.031-26', '2026-09-20', 'Изменение крепления корпуса', '230');
INSERT INTO doc_change VALUES
 (2, 1, 1, '2026-09-16', '1'),
 (3, 1, 1, '2026-09-16', '2');
INSERT INTO subscription VALUES ('310', 1, 2, '2026-03-20'), ('310', 3, 2, '2026-03-20');
INSERT INTO sign_role VALUES
 ('РАЗР', 'Разработал'), ('ПРОВ', 'Проверил'), ('ТКОНТР', 'Технический контроль'),
 ('НКОНТР', 'Нормоконтроль'), ('УТВ', 'Утвердил');
INSERT INTO signature VALUES
 (1, 'РАЗР',   1043, '2026-03-02'),
 (1, 'ПРОВ',   1051, '2026-03-04'),
 (1, 'НКОНТР', 2007, '2026-03-06'),
 (1, 'УТВ',    1002, '2026-03-10'),
 (2, 'РАЗР',   1043, '2026-03-02');

\echo '--- Ошибочные вставки (каждая должна быть отклонена) ---'
\echo '1) Корпус в составе платы в количестве 0'
INSERT INTO product_part VALUES (3, 2, 0);
\echo '2) Блок питания входит в собственный корпус (цикл состава)'
INSERT INTO product_part VALUES (2, 1, 1);
\echo '3) Второй сборочный чертёж блока питания'
INSERT INTO document (product_id, doc_code, sheet_format, sheets, litera, received_date)
VALUES (1, 'СБ', 'A1', 1, 'О1', '2026-04-01');
\echo '4) Изменение схемы блока по извещению КБ-3'
INSERT INTO doc_change VALUES (2, 2, 2, '2026-09-21', '1');
\echo '5) Изменение 3 схемы при отсутствии изменения 2'
INSERT INTO doc_change VALUES (2, 3, 1, '2026-09-17', '1');
\echo '6) Кравец О. Н. проверяет собственную схему'
INSERT INTO signature VALUES (2, 'ПРОВ', 1043, '2026-03-04');
\echo '7) Подписка несуществующего подразделения 999'
INSERT INTO subscription VALUES ('999', 1, 1, '2026-04-01');

\echo '--- Итог: строки таблиц ---'
SELECT p.designation || ' ' || d.doc_code AS document, c.change_no, n.notice_no, c.change_date
  FROM doc_change c JOIN document d USING (document_id) JOIN product p USING (product_id)
  JOIN notice n USING (notice_id) ORDER BY 1;
SELECT r.name AS role, e.full_name, s.sign_date FROM signature s
  JOIN sign_role r USING (role_code) JOIN employee e USING (employee_id)
 WHERE s.document_id = 1 ORDER BY s.sign_date;

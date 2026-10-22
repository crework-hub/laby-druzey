-- Задания к лекции «Нормализация баз данных». Школа (вариант 14), SQLite (DBeaver)
-- Литвинов Р.А., группа 25-СТ
PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS schedule;
DROP TABLE IF EXISTS teacher;
DROP TABLE IF EXISTS subject;
DROP TABLE IF EXISTS school_class;
DROP TABLE IF EXISTS workload_3nf;
DROP TABLE IF EXISTS lesson_raw;

-- 0. Исходная таблица УРОК (как в задании + 3 своих строки), PK (дата, класс).
-- Значения атомарны, поэтому таблица уже в 1НФ, но в ней повторяются учитель, предмет и кабинет.
CREATE TABLE lesson_raw (
    lesson_date TEXT    NOT NULL,   -- дата
    class_name  TEXT    NOT NULL,   -- класс
    subject     TEXT    NOT NULL,   -- предмет
    teacher     TEXT    NOT NULL,   -- учитель
    room        INTEGER NOT NULL,   -- кабинет
    topic       TEXT    NOT NULL,   -- тема
    PRIMARY KEY (lesson_date, class_name)
);
INSERT INTO lesson_raw VALUES ('2024-03-01', '5А', 'Математика', 'Смирнов А.А.',  201, 'Дроби');
INSERT INTO lesson_raw VALUES ('2024-03-01', '5Б', 'Математика', 'Смирнов А.А.',  201, 'Дроби');
INSERT INTO lesson_raw VALUES ('2024-03-01', '6А', 'Русский',    'Никитина О.О.', 305, 'Сложное предложение');
INSERT INTO lesson_raw VALUES ('2024-03-02', '5А', 'Математика', 'Смирнов А.А.',  201, 'Проценты');
-- свои строки
INSERT INTO lesson_raw VALUES ('2024-03-02', '6А', 'Математика', 'Белова Е.В.',   204, 'Уравнения');
INSERT INTO lesson_raw VALUES ('2024-03-02', '5Б', 'Русский',    'Никитина О.О.', 305, 'Глагол');
INSERT INTO lesson_raw VALUES ('2024-03-03', '5А', 'Русский',    'Никитина О.О.', 305, 'Глагол');

-- 0а. Промежуточная 3НФ-таблица НАГРУЗКА (класс, предмет, учитель): кто ведёт предмет в классе.
-- ФЗ: (класс, предмет) -> учитель и учитель -> предмет. Ключи: (класс, предмет) и (класс, учитель).
-- Все атрибуты ключевые, поэтому 3НФ выполняется, но детерминант «учитель» не ключ -> НФБК нарушена.
CREATE TABLE workload_3nf (
    class_name TEXT NOT NULL,
    subject    TEXT NOT NULL,
    teacher    TEXT NOT NULL,
    PRIMARY KEY (class_name, subject),
    UNIQUE (class_name, teacher)
);
INSERT INTO workload_3nf SELECT DISTINCT class_name, subject, teacher FROM lesson_raw;

-- 1. Классы (справочник): CHECK — цифра(ы) класса и заглавная русская буква
CREATE TABLE school_class (
    class_name TEXT PRIMARY KEY,
    CONSTRAINT ck_class_name CHECK (class_name GLOB '[1-9][А-Я]' OR class_name GLOB '1[01][А-Я]')
);

-- 2. Предметы (справочник): предмет существует, даже если по нему нет уроков
CREATE TABLE subject (
    subject_id INTEGER PRIMARY KEY,
    name       TEXT NOT NULL,
    CONSTRAINT uq_subject_name UNIQUE (name),
    CONSTRAINT ck_subject_name CHECK (LENGTH(TRIM(name)) > 0)
);

-- 3. Учителя (УЧИТЕЛЬ_ПРЕДМЕТ): учитель -> предмет, кабинет
CREATE TABLE teacher (
    teacher_id INTEGER PRIMARY KEY,
    full_name  TEXT    NOT NULL,
    subject_id INTEGER NOT NULL,
    room       INTEGER NOT NULL,
    CONSTRAINT uq_teacher_name    UNIQUE (full_name),
    CONSTRAINT fk_teacher_subject FOREIGN KEY (subject_id) REFERENCES subject (subject_id),
    CONSTRAINT ck_teacher_room    CHECK (room BETWEEN 100 AND 599)
);

-- 4. Расписание (РАСПИСАНИЕ): (дата, класс) -> учитель, тема
CREATE TABLE schedule (
    lesson_date TEXT    NOT NULL,
    class_name  TEXT    NOT NULL,
    teacher_id  INTEGER NOT NULL,
    topic       TEXT    NOT NULL,
    CONSTRAINT pk_schedule PRIMARY KEY (lesson_date, class_name),
    CONSTRAINT fk_schedule_class   FOREIGN KEY (class_name) REFERENCES school_class (class_name),
    CONSTRAINT fk_schedule_teacher FOREIGN KEY (teacher_id) REFERENCES teacher (teacher_id),
    CONSTRAINT ck_schedule_date    CHECK (DATE(lesson_date) IS lesson_date),
    CONSTRAINT ck_schedule_topic   CHECK (LENGTH(TRIM(topic)) > 0)
);

-- Данные (строки из исходной таблицы + собственные)
INSERT INTO school_class (class_name) VALUES ('5А'), ('5Б'), ('6А'), ('6Б'), ('7А');

INSERT INTO subject (subject_id, name) VALUES
    (1, 'Математика'), (2, 'Русский'), (3, 'Литература'), (4, 'История'), (5, 'Физика');

INSERT INTO teacher (teacher_id, full_name, subject_id, room) VALUES
    (1, 'Смирнов А.А.',   1, 201),
    (2, 'Никитина О.О.',  2, 305),
    (3, 'Белова Е.В.',    1, 204),
    (4, 'Кузнецова Т.М.', 3, 306),
    (5, 'Орлов П.Д.',     4, 410);

INSERT INTO schedule (lesson_date, class_name, teacher_id, topic) VALUES
    ('2024-03-01', '5А', 1, 'Дроби'),
    ('2024-03-01', '5Б', 1, 'Дроби'),
    ('2024-03-01', '6А', 2, 'Сложное предложение'),
    ('2024-03-02', '5А', 1, 'Проценты'),
    ('2024-03-02', '6А', 3, 'Уравнения'),
    ('2024-03-02', '5Б', 2, 'Глагол'),
    ('2024-03-03', '5А', 2, 'Глагол');

-- ===== Проверочные запросы =====
-- Проверка ФЗ по данным: сколько разных учителей/кабинетов у предмета и сколько предметов у учителя
SELECT 'предмет -> учитель' AS fd, subject AS value, COUNT(DISTINCT teacher) AS variants FROM lesson_raw GROUP BY subject
UNION ALL
SELECT 'учитель -> предмет', teacher, COUNT(DISTINCT subject) FROM lesson_raw GROUP BY teacher
UNION ALL
SELECT 'учитель -> кабинет', teacher, COUNT(DISTINCT room) FROM lesson_raw GROUP BY teacher;

-- Демонстрация аномалий на исходной таблице (изменения отменяются)
SAVEPOINT demo;
UPDATE lesson_raw SET room = 202 WHERE lesson_date = '2024-03-01' AND class_name = '5А';
SELECT DISTINCT teacher, room FROM lesson_raw WHERE teacher = 'Смирнов А.А.';   -- 2 разных кабинета
DELETE FROM lesson_raw WHERE lesson_date = '2024-03-02' AND class_name = '6А';
SELECT COUNT(*) AS found FROM lesson_raw WHERE teacher = 'Белова Е.В.';        -- 0: учитель и её кабинет потеряны
ROLLBACK TO demo;
RELEASE demo;

-- Q0. НФБК: аномалии 3НФ-таблицы НАГРУЗКА (учитель -> предмет, но «учитель» не ключ)
SAVEPOINT bcnf;
INSERT INTO workload_3nf VALUES ('6Б', 'Русский', 'Смирнов А.А.');              -- принято: у Смирнова 2 предмета
SELECT teacher, COUNT(DISTINCT subject) AS subjects FROM workload_3nf GROUP BY teacher HAVING COUNT(DISTINCT subject) > 1;
DELETE FROM workload_3nf WHERE class_name = '6А' AND subject = 'Математика';
SELECT COUNT(*) AS belova_rows FROM workload_3nf WHERE teacher = 'Белова Е.В.';  -- 0: что Белова ведёт математику, забыто
ROLLBACK TO bcnf;
RELEASE bcnf;

-- Q1. Восстановление исходной таблицы УРОК соединением (JOIN)
SELECT s.lesson_date, s.class_name, sb.name AS subject, t.full_name AS teacher, t.room, s.topic
FROM schedule s
JOIN teacher t  ON t.teacher_id  = s.teacher_id
JOIN subject sb ON sb.subject_id = t.subject_id
ORDER BY s.lesson_date, s.class_name;
-- Q2. Проверка сохранности данных: строки исходной таблицы, которых нет в соединении (ожидается 0)
SELECT COUNT(*) AS lost_rows FROM (
  SELECT lesson_date, class_name, subject, teacher, room, topic FROM lesson_raw
  EXCEPT
  SELECT s.lesson_date, s.class_name, sb.name, t.full_name, t.room, s.topic
  FROM schedule s JOIN teacher t ON t.teacher_id = s.teacher_id
  JOIN subject sb ON sb.subject_id = t.subject_id);
-- Q3. Контроль ФЗ (класс, предмет) -> учитель, которую НФБК не проверяет ключом (ожидается 0 строк)
SELECT s.class_name, t.subject_id, COUNT(DISTINCT t.teacher_id) AS teachers
FROM schedule s JOIN teacher t ON t.teacher_id = s.teacher_id
GROUP BY s.class_name, t.subject_id HAVING COUNT(DISTINCT t.teacher_id) > 1;
-- Q4. UPDATE: кабинет учителя меняется в одной строке, а не во всех его уроках
UPDATE teacher SET room = 202 WHERE full_name = 'Смирнов А.А.';
SELECT s.lesson_date, s.class_name, t.full_name, t.room FROM schedule s JOIN teacher t ON t.teacher_id = s.teacher_id WHERE t.teacher_id = 1;
-- Q5. DELETE: удаление единственного урока Беловой не удаляет учителя и предмет
DELETE FROM schedule WHERE lesson_date = '2024-03-02' AND class_name = '6А';
SELECT t.full_name, sb.name AS subject, t.room FROM teacher t JOIN subject sb ON sb.subject_id = t.subject_id WHERE t.full_name = 'Белова Е.В.';
-- Q6. Количество учителей и уроков по каждому предмету (LEFT JOIN + GROUP BY)
SELECT sb.name AS subject, COUNT(DISTINCT t.teacher_id) AS teachers, COUNT(s.lesson_date) AS lessons
FROM subject sb
LEFT JOIN teacher  t ON t.subject_id = sb.subject_id
LEFT JOIN schedule s ON s.teacher_id = t.teacher_id
GROUP BY sb.subject_id ORDER BY sb.subject_id;

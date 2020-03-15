module monetdb.monetdb;

import std.string;
import std.exception;
import std.conv;
import std.datetime;
import std.range;
import std.variant;

import monetdb.binding;

alias Null = typeof(null);

//TODO: support const type as well
alias Record = Algebraic!(int, short, long, double, char, bool, string, Date, DateTime, Null);

class MonetDbException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

protected Record dize(T)(const T typeName, const T value)
if (is(T : string)) {
    Record res;
    if(value == "") {
        res = null;
        return res;
    }
    if(typeName == "int") {
        res = value.to!int;
    } else if (typeName == "tinyint") {
        res = value.to!short;
    } else if (typeName == "bigint") {
        res = value.to!long;
    } else if(typeName == "double") {
        res = value.to!double;
    } else if (typeName == "date") {
        res = Date.fromISOExtString(value.to!string);
    } else if (typeName == "timestamp") {
        auto toExtISOFormat = (const string d) => d[0 .. 10] ~ "T" ~ d[11 .. 19];
        res = DateTime.fromISOExtString(toExtISOFormat(value.to!string));
    } else if (typeName == "varchar" || typeName == "char") {
        res = value.to!string;
    } else {
        enforce!MonetDbException(false, "Could not d-ize type: " ~ typeName);
    }
    return res;
}

protected MapiDate monetizeDate(const Date date) {
    return MapiDate(date.year, date.month, date.day);
}

protected MapiDateTime monetizeDateTime(const DateTime date) {
    return MapiDateTime(
        date.year, date.month, date.day, date.hour, date.minute, date.second, 0);
}

Record[] recordArray(T...)(T params) {
    Record[] records;
    foreach(i, p; params) {
        records ~= Record(p);
    }
    return records;
}

class MonetDb {
    private Mapi _mapi;

    this(string host, int port, string username, string password, string lang, string dbname) @trusted {
        _mapi = mapi_connect(
            toStringz(host),
            port,
            toStringz(username),
            toStringz(password),
            toStringz(lang),
            toStringz(dbname));
    }

    ~this() {
        mapi_destroy(_mapi);
    }

    private string errorMessage(MapiHdl handler) {
        auto msg = mapi_error_str(_mapi);
        if(msg) {
            return to!string(msg);
        }
        return to!string(mapi_result_error(handler));
    }

    private int getMapiType(Record p) {
        return p.visit!(
            (int a) => MAPI_INT,
            (short a) => MAPI_SHORT,
            (long a) => MAPI_LONG,
            (char a) => MAPI_CHAR,
            (string a) => MAPI_VARCHAR,
            (double a) => MAPI_DOUBLE,
            (Date a) => MAPI_DATE,
            (DateTime a) => MAPI_DATETIME,
            (bool a) => MAPI_USHORT,
            (Null a) => -1
        )();
    }

    private MapiHdl buildHandler(string command, Record[] params) {
        MapiHdl result;
        if (params is null) {
            result = mapi_query(_mapi, toStringz(command));
        } else {
            result = mapi_prepare(_mapi, toStringz(command));
            foreach(i, p; params) {
                auto mapiType = getMapiType(p);
                enforce!MonetDbException(mapiType >= 0, "Parameter having a null value are not supported!");
                if(p.type == typeid(Date)) {
                    auto d = p.get!Date.monetizeDate;
                    mapi_param_type(result, i.to!int, mapiType, mapiType, &d);
                } else if (p.type == typeid(DateTime)) {
                    auto d = p.get!DateTime.monetizeDateTime;
                    mapi_param_type(result, i.to!int, mapiType, mapiType, &d);
                } else if (p.type == typeid(string)) {
                    auto s = cast(char*)p.get!string.toStringz;
                    mapi_param_type(result, i.to!int, mapiType, mapiType, s);
                } else if (p.type == typeid(int)) {
                    auto v = p.get!int;
                    mapi_param_type(result, i.to!int, mapiType, mapiType, &v);
                } else if (p.type == typeid(long)) {
                    auto v = p.get!long;
                    mapi_param_type(result, i.to!int, mapiType, mapiType, &v);
                } else if (p.type == typeid(double)) {
                    auto v = p.get!double;
                    mapi_param_type(result, i.to!int, mapiType, mapiType, &v);
                } else if (p.type == typeid(char)) {
                    auto v = p.get!char;
                    mapi_param_type(result, i.to!int, mapiType, mapiType, &v);
                } else if (p.type == typeid(bool)) {
                    auto v = p.get!bool;
                    mapi_param_type(result, i.to!int, mapiType, mapiType, &v);
                } else {
                    assert(false);
                }
            }
            mapi_execute(result);
        }
        enforce!MonetDbException(mapi_error(_mapi) == MOK, errorMessage(result));

        return result;
    }

    void exec(string command, Record[] params = null) {
        auto result = buildHandler(command, params);
        mapi_close_handle(result);
    }

    auto query(string command, Record[] params = null) {
        auto result = buildHandler(command, params);

        static struct QueryResult {
            private MapiHdl handler_;
            private bool hasRow_;
            private int count_;

            this(MapiHdl handler) {
                handler_ = handler;
                fetchRow();
            }

            auto empty() {
                return !hasRow_;
            }

            private void fetchRow() {
                hasRow_ = mapi_fetch_row(handler_) == 0 ? false : true;
                count_ = mapi_get_field_count(handler_);
            }

            auto front() {
                assert(!empty);

                Record[string] records;
                foreach(i; iota(count_)) {
                    auto name = mapi_get_name(handler_, i).to!string;
                    auto typeName = mapi_get_type(handler_, i).to!string;
                    auto value = mapi_fetch_field(handler_, i).to!string;
                    records[name] = dize(typeName, value);
                }
                return records;
            }

            void popFront() {
                assert(!empty);
                fetchRow();
                if(!hasRow_) mapi_close_handle(handler_);
            }
        }

        return QueryResult(result);
    }

    void close() {
        mapi_disconnect(_mapi);
    }
}

unittest {
    auto conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "16megabytes");
    scope(exit) conn.close();

    conn.exec("DROP TABLE IF EXISTS FOO;");
    conn.exec(
        `CREATE TABLE IF NOT EXISTS FOO (
            ID INTEGER NOT NULL,
            VALUE VARCHAR(5),
            RATIO DOUBLE,
            CREATION DATE,
            SYSDATE TIMESTAMP DEFAULT NOW,
            FLAG BOOLEAN DEFAULT FALSE,
            UNIT CHAR DEFAULT 'U'
        );`);
    conn.exec("INSERT INTO FOO (ID, VALUE, RATIO, CREATION) VALUES (1, 'foo', .5, '2018-01-01');");
    Record[] p1 = recordArray(2, "bar", .63, Date(2018, 1, 1));
    conn.exec("INSERT INTO FOO (ID, VALUE, RATIO, CREATION) VALUES (?, ?, ?, ?);", p1);
    Record[] p2 = recordArray(3, Date(2019, 3, 31));
    conn.exec("INSERT INTO FOO (ID, CREATION) VALUES (?, ?)", p2);

    auto r = conn.query("SELECT ID, VALUE, CREATION, SYSDATE, RATIO FROM FOO ORDER BY ID");
    auto row = r.front;
    assert("id" in row);
    assert("value" in row);
    assert("creation" in row);
    assert(row["id"].get!int == 1);
    assert(row["value"].get!string == "foo");
    assert(row["creation"].get!Date == Date(2018, 1, 1));
    r.popFront();
    auto row2 = r.front;
    assert(row2["id"].get!int == 2);
    assert(row2["value"].get!string == "bar");
    assert(row2["creation"].get!Date == Date(2018, 1, 1));
    r.popFront();
    auto row3 = r.front;
    assert(row3["value"].get!Null is null);
    assert(row3["ratio"].get!Null is null);

    Record[] params = recordArray(1, "foo");
    auto rp = conn.query("SELECT ID, VALUE, RATIO, CREATION FROM FOO WHERE ID = ? AND VALUE = ?", params);
    assert(rp.front["id"].get!int == 1);
    assert(rp.front["value"].get!string == "foo");
    assert(rp.front["ratio"].get!double == .5);
    assert(rp.front["creation"].get!Date == Date(2018, 1, 1));

    auto rl = conn.query(
        "SELECT COUNT(*) AS V, ID FROM FOO WHERE FLAG = ? AND SYSDATE > ? AND UNIT = ? GROUP BY ID HAVING COUNT(*) = ?;",
        recordArray(false, DateTime(1970, 1, 1, 0, 0, 0), 'U', 1L));
    assert(rl.front["v"].get!long == 1L);

    conn.exec("DROP TABLE FOO;");
}

unittest {
    auto conn = new MonetDb("localhost", 50_000, "monetdb", "monetdb", "sql", "16megabytes");
    scope(exit) conn.close();

    conn.exec("CREATE TABLE IF NOT EXISTS FOO (ID INT); INSERT INTO FOO (ID) VALUES (1), (2); DROP TABLE FOO;");
}
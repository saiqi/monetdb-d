module monetdb.binding;

import std.string;
import core.stdc.stdio: FILE;

enum {
    MAPI_AUTO       = 0,
    MAPI_TINY       = 1,
    MAPI_UTINY      = 2,
    MAPI_SHORT      = 3,
    MAPI_USHORT     = 4,
    MAPI_INT        = 5,
    MAPI_UINT       = 6,
    MAPI_LONG       = 7,
    MAPI_ULONG      = 8,
    MAPI_LONGLONG   = 9,
    MAPI_ULONGLONG  = 10,
    MAPI_CHAR       = 11,
    MAPI_VARCHAR    = 12,
    MAPI_FLOAT      = 13,
    MAPI_DOUBLE     = 14,
    MAPI_DATE       = 15,
    MAPI_TIME       = 16,
    MAPI_DATETIME   = 17,
    MAPI_NUMERIC    = 18
}

enum int PLACEHOLDER = '?';

enum {
    MAPI_SEEK_SET   = 0,
    MAPI_SEEK_CUR   = 1,
    MAPI_SEEK_END   = 2
}

alias MapiMsg = int;

enum {
    MOK             = 0,
    MERROR          = -1,
    MTIMEOUT        = -2,
    MMORE           = -3,
    MSERVER         = -4
}

enum int PROMPTBEG = '\001';
enum const(char*) PROMPT1 = "\001\001\n".ptr;
enum const(char*) PROMPT2 = "\001\002\n".ptr;
enum const(char*) PROMPT3 = "\001\003\n".ptr;

struct MapiStruct;
alias Mapi = MapiStruct*;

enum sql_query_t {
    Q_PARSE = 0,
    Q_TABLE = 1,
    Q_UPDATE = 2,
    Q_SCHEMA = 3,
    Q_TRANS = 4,
    Q_PREPARE = 5,
    Q_BLOCK = 6
}


struct MapiStatement;
alias MapiHdl = MapiStatement*;

struct MapiDate {
    short year;
    ushort month;
    ushort day;
}

struct MapiTime {
    ushort hour;
    ushort minute;
    ushort second;
}

struct MapiDateTime {
    short year;
    ushort month;
    ushort day;
    ushort hour;
    ushort minute;
    ushort second;
    uint fraction;
}

extern(C) {
    Mapi mapi_mapi (const(char)* host, int port, const(char)* username, const(char)* password, const(char)* lang, const(char)* dbname);
    Mapi mapi_mapiuri (const(char)* url, const(char)* user, const(char)* pass, const(char)* lang);
    MapiMsg mapi_destroy (Mapi mid);
    MapiMsg mapi_start_talking (Mapi mid);
    Mapi mapi_connect (const(char)* host, int port, const(char)* username, const(char)* password, const(char)* lang, const(char)* dbname);
    char** mapi_resolve (const(char)* host, int port, const(char)* pattern);
    MapiMsg mapi_disconnect (Mapi mid);
    MapiMsg mapi_reconnect (Mapi mid);
    MapiMsg mapi_ping (Mapi mid);
    void mapi_setfilecallback (
        Mapi mid,
        char* function (void* priv, const(char)* filename, bool binary, ulong offset, size_t* size) getfunc,
        char* function (void* priv, const(char)* filename, const(void)* data, size_t size) putfunc,
        void* priv);

    MapiMsg mapi_error (Mapi mid);
    const(char)* mapi_error_str (Mapi mid);
    void mapi_noexplain (Mapi mid, const(char)* errorprefix);
    void mapi_explain (Mapi mid, FILE* fd);
    void mapi_explain_query (MapiHdl hdl, FILE* fd);
    void mapi_explain_result (MapiHdl hdl, FILE* fd);
    void mapi_trace (Mapi mid, bool flag);

    bool mapi_get_trace (Mapi mid);
    bool mapi_get_autocommit (Mapi mid);
    MapiMsg mapi_log (Mapi mid, const(char)* nme);
    MapiMsg mapi_setAutocommit (Mapi mid, bool autocommit);
    MapiMsg mapi_set_size_header (Mapi mid, bool value);
    MapiMsg mapi_release_id (Mapi mid, int id);
    const(char)* mapi_result_error (MapiHdl hdl);
    const(char)* mapi_result_errorcode (MapiHdl hdl);
    MapiMsg mapi_next_result (MapiHdl hdl);
    MapiMsg mapi_needmore (MapiHdl hdl);
    bool mapi_more_results (MapiHdl hdl);
    MapiHdl mapi_new_handle (Mapi mid);
    MapiMsg mapi_close_handle (MapiHdl hdl);
    MapiMsg mapi_bind (MapiHdl hdl, int fnr, char** ptr);
    MapiMsg mapi_bind_var (MapiHdl hdl, int fnr, int type, void* ptr);
    MapiMsg mapi_bind_numeric (MapiHdl hdl, int fnr, int scale, int precision, void* ptr);
    MapiMsg mapi_clear_bindings (MapiHdl hdl);
    MapiMsg mapi_param_type (MapiHdl hdl, int fnr, int ctype, int sqltype, void* ptr);
    MapiMsg mapi_param_string (MapiHdl hdl, int fnr, int sqltype, char* ptr, int* sizeptr);
    MapiMsg mapi_param (MapiHdl hdl, int fnr, char** ptr);
    MapiMsg mapi_param_numeric (MapiHdl hdl, int fnr, int scale, int precision, void* ptr);
    MapiMsg mapi_clear_params (MapiHdl hdl);
    MapiHdl mapi_prepare (Mapi mid, const(char)* cmd);
    MapiMsg mapi_prepare_handle (MapiHdl hdl, const(char)* cmd);
    MapiMsg mapi_execute (MapiHdl hdl);
    MapiMsg mapi_fetch_reset (MapiHdl hdl);
    MapiMsg mapi_finish (MapiHdl hdl);
    MapiHdl mapi_query (Mapi mid, const(char)* cmd);
    MapiMsg mapi_query_handle (MapiHdl hdl, const(char)* cmd);
    MapiHdl mapi_query_prep (Mapi mid);
    MapiMsg mapi_query_part (MapiHdl hdl, const(char)* cmd, size_t size);
    MapiMsg mapi_query_done (MapiHdl hdl);
    MapiHdl mapi_send (Mapi mid, const(char)* cmd);
    MapiMsg mapi_read_response (MapiHdl hdl);
    MapiMsg mapi_cache_limit (Mapi mid, int limit);
    MapiMsg mapi_cache_freeup (MapiHdl hdl, int percentage);
    MapiMsg mapi_seek_row (MapiHdl hdl, long rowne, int whence);

    MapiMsg mapi_timeout (Mapi mid, uint time);
    int mapi_fetch_row (MapiHdl hdl);
    long mapi_fetch_all_rows (MapiHdl hdl);
    int mapi_get_field_count (MapiHdl hdl);
    long mapi_get_row_count (MapiHdl hdl);
    long mapi_get_last_id (MapiHdl hdl);
    long mapi_rows_affected (MapiHdl hdl);
    long mapi_get_querytime (MapiHdl hdl);
    long mapi_get_maloptimizertime (MapiHdl hdl);
    long mapi_get_sqloptimizertime (MapiHdl hdl);

    char* mapi_fetch_field (MapiHdl hdl, int fnr);
    size_t mapi_fetch_field_len (MapiHdl hdl, int fnr);
    MapiMsg mapi_store_field (MapiHdl hdl, int fnr, int outtype, void* outparam);
    char* mapi_fetch_line (MapiHdl hdl);
    int mapi_split_line (MapiHdl hdl);
    const(char)* mapi_get_lang (Mapi mid);
    const(char)* mapi_get_uri (Mapi mid);
    const(char)* mapi_get_dbname (Mapi mid);
    const(char)* mapi_get_host (Mapi mid);
    const(char)* mapi_get_user (Mapi mid);
    const(char)* mapi_get_mapi_version (Mapi mid);
    const(char)* mapi_get_monet_version (Mapi mid);
    const(char)* mapi_get_motd (Mapi mid);
    bool mapi_is_connected (Mapi mid);
    char* mapi_get_table (MapiHdl hdl, int fnr);
    char* mapi_get_name (MapiHdl hdl, int fnr);
    char* mapi_get_type (MapiHdl hdl, int fnr);
    int mapi_get_len (MapiHdl hdl, int fnr);
    int mapi_get_digits (MapiHdl hdl, int fnr);
    int mapi_get_scale (MapiHdl hdl, int fnr);
    char* mapi_get_query (MapiHdl hdl);
    int mapi_get_querytype (MapiHdl hdl);
    int mapi_get_tableid (MapiHdl hdl);
    char* mapi_quote (const(char)* msg, int size);
    char* mapi_unquote (char* msg);
    MapiHdl mapi_get_active (Mapi mid);
}
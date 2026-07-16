#ifndef _MYSQL_CLI_H_
#define _MYSQL_CLI_H_

// Validaciones
extern int valida_operacion(struct iso8583* iso, char* bm_req);

extern int valida_cvv(MYSQL* con, struct iso8583* iso);

extern int valida_cupon(MYSQL *con, struct iso8583* iso, int rever);
extern int valida_cupon_dup(MYSQL *con, struct iso8583* iso);
extern int valida_cupon_reverso(MYSQL *con, struct iso8583* iso);

extern int valida_terminal(MYSQL* con, struct iso8583* iso);
extern int valida_terminal_comercio(MYSQL* con, struct iso8583* iso);

extern char* getComercioByTerminalID(MYSQL* con, struct iso8583* iso);

extern int valida_comercio(MYSQL* con, struct iso8583* iso);

extern int valida_usuario(MYSQL* con, struct iso8583* iso);
extern int valida_usuario_existe(MYSQL* con, struct iso8583* iso);
extern int valida_usuario_vigencia(MYSQL* con, struct iso8583* iso);
extern int valida_usuario_producto(MYSQL* con, struct iso8583* iso);

extern int venta_cupon(struct iso8583* iso);
extern int anula_cupon(struct iso8583* iso, struct iso8583* iso_tmp);
extern int consulta_saldo(struct iso8583* iso);
extern int devolucion(struct iso8583* iso);
extern int reverso(struct iso8583* iso);
extern int reversa_cupon(MYSQL *con, struct iso8583* iso);
extern int cierre_lote(struct iso8583* iso);

extern char* getUserProds(MYSQL* con, char* nroTarjeta);

extern int auth_write_cvv(MYSQL *con, char* cvv, char* ndoc);
extern char* auth_genera_cvv(int ndoc);
extern int denuncia_perdida(struct iso8583* iso);

extern double calcula_consumo_vivo(MYSQL* con, char* card_number, int byTerm, struct iso8583* iso);
extern double calcula_consumo_vivo_acum(MYSQL *con, char* card_number, int byTerm, struct iso8583* iso);

extern int validaIntMoneda(MYSQL* con, char* codMoneda); // verifica la validacion de enteros
extern int validaCantidadTK(MYSQL* con, char* codMoneda); // valida cantidad de unidades de producto pot TK

extern double calcula_saldo_anterior(MYSQL* con, char* card_number, char* codMoneda);
extern double calcula_descubierto(MYSQL *con, char* prod_id);
extern double saldo_anterior_comercio(MYSQL *con, char* comer_id, char* codMoneda);
extern double getProdAmount(MYSQL* con, char* codMoneda);

// common
extern char* getVencimiento(struct iso8583* iso);
extern char* getCardNumber(struct iso8583* iso);
extern double getAmount(struct iso8583* iso);
extern char* getProduct(struct iso8583* iso);
extern int getLoteID(struct iso8583* iso);

extern int getLoteIdFromCUP(MYSQL *con, struct iso8583* iso, struct iso8583* iso_tmp, int flag);
extern int getMonedaFromCUP(MYSQL *con, struct iso8583* iso, struct iso8583* iso_tmp, int flag);

extern int getCierreVentas(MYSQL *con, struct iso8583* iso, int* cV, double* tV, int* cA, double* tA, int* cD, double* tD);

extern char* retcode_to_str(int err_code);


// graba ISO en tabla ISO_POOL
// si inout == 1 -> guarda ISO (in)
// si inout == 2 -> guarda ISO (out)
extern int guardar_iso(MYSQL* con, struct iso8583* iso, int inout);

int informa_subsidio(MYSQL* con, struct iso8583* iso);
int obtieneUltimaRecarga(MYSQL* con, char* card_number, char* codMoneda, double* montoUltimaRecarga);
int validaTiempoUltimaVenta(MYSQL* con, char* card_number, char* codMoneda);
int obtieneConfiguracion(MYSQL *con, const char *name, char *out_val_char, int *out_val_int);
#endif

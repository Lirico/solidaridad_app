// Decompiled by Jad v1.5.8e. Copyright 2001 Pavel Kouznetsov.
// Jad home page: http://www.geocities.com/kpdus/jad.html
// Decompiler options: packimports(3) 
// Source File Name:   awsTest001.java

package aws;

import com.mysql.jdbc.ResultSet;
import com.mysql.jdbc.Statement;
import java.io.PrintStream;
import java.sql.*;
import java.util.*;

// Referenced classes of package aws:
//            ComerRepo, Diaria

public class awsTest001
{

    public awsTest001()
    {
        try
        {
            Class.forName("com.mysql.jdbc.Driver").newInstance();
        }
        catch(Exception ex) { }
    }

    private List getVivosFromDB(String sess, String comer, String termid, String dni)
    {
        System.out.println("getDiariaComerFromDB() INIT ");
        Connection con = null;
        Statement st = null;
        ResultSet rs = null;
        String sql2 = null;
        boolean useByTraco = false;
        if(comer.equalsIgnoreCase("null"))
            useByTraco = true;
        if(termid.equalsIgnoreCase("null"))
            termid = "%";
        if(dni.equalsIgnoreCase("null"))
            dni = "%";
        String url = "jdbc:mysql://192.168.1.1:3306/kigsolidario2";
        String db_user = "kigadmin2";
        String db_password = "mar89$an2-";
        List periodo = new ArrayList();
        try
        {
            con = DriverManager.getConnection(url, db_user, db_password);
            System.out.println("getDiariaComerFromDB() ON_CONNECT ");
            if(useByTraco)
            {
                System.out.println("getDiariaComerFromDB() TRACO = OK ");
                String razon_social = getRazonSocial(con, sess);
                sql2 = (new StringBuilder()).append("call ReporteProveedoresByCUP('").append(razon_social).append("', '").append(termid).append("', '").append(dni).append("')").toString();
                System.out.println((new StringBuilder()).append("getDiariaComerFromDB() SQL = \n ").append(sql2).toString());
            } else
            {
                System.out.println("getDiariaComerFromDB() TRACO = NOK ");
                sql2 = (new StringBuilder()).append("call ReporteProveedoresByCUP2('").append(comer).append("', '").append(termid).append("', '").append(dni).append("')").toString();
                System.out.println((new StringBuilder()).append("getDiariaComerFromDB() SQL = \n ").append(sql2).toString());
            }
            st = (Statement)con.createStatement();
            st.execute(sql2);
            ComerRepo dia;
            for(rs = (ResultSet)st.getResultSet(); rs.next(); periodo.add(dia))
            {
                dia = new ComerRepo();
                dia.setComer_id(rs.getString("COMER_ID"));
                dia.setProd_id(rs.getString("PROD_ID"));
                dia.setTerm_date(rs.getString("TERM_DATE"));
                dia.setTerm_time(rs.getString("TERM_TIME"));
                dia.setTerm_id(rs.getString("TERM_ID"));
                dia.setAuth_code(rs.getString("AUTH_CODE"));
                dia.setLote_id(rs.getString("LOTE_ID"));
                dia.setNum_cupon(rs.getString("NUM_CUPON"));
                dia.setCantidad(rs.getString("CANTIDAD"));
                dia.setCantidad_kig(rs.getString("CANTIDAD_KIG"));
                dia.setAnulado(rs.getString("ANULADO"));
                dia.setConcepto(rs.getString("CONCEPTO"));
                dia.setNro_tarjeta(rs.getString("NRO_TARJETA"));
                dia.setApellido_nombre(rs.getString("APELLIDO_NOMBRE"));
                dia.setDni(rs.getString("DNI"));
                dia.setLocalidad(rs.getString("LOCALIDAD"));
                dia.setDomicilio(rs.getString("DOMICILIO"));
                dia.setId_trans(rs.getString("ID_TRANS"));
            }

        }
        catch(SQLException ex)
        {
            System.out.println((new StringBuilder()).append("getDiariaComerFromDB() EXCEP: ").append(ex.getMessage()).toString());
        }
        System.out.println("getDiariaComerFromDB() END ");
        return periodo;
    }

    private List getDiariaComerFromDB(String sess, String comer, String termid, String dni, String fecha_ini, String fecha_fin)
    {
        System.out.println("getDiariaComerFromDB() INIT ");
        Connection con = null;
        Statement st = null;
        ResultSet rs = null;
        Statement st2 = null;
        ResultSet rs2 = null;
        String sql = null;
        String sql2 = null;
        boolean useByTraco = false;
        if(comer.equalsIgnoreCase("null"))
            useByTraco = true;
        if(termid.equalsIgnoreCase("null"))
            termid = "%";
        if(dni.equalsIgnoreCase("null"))
            dni = "%";
        if(fecha_ini.equalsIgnoreCase("null"))
            fecha_ini = "CURRENT_DATE()";
        if(fecha_fin.equalsIgnoreCase("null"))
            fecha_ini = "CURRENT_DATE()";
        String url = "jdbc:mysql://192.168.1.1:3306/kigsolidario2";
        String db_user = "kigadmin2";
        String db_password = "mar89$an2-";
        List periodo = new ArrayList();
        try
        {
            con = DriverManager.getConnection(url, db_user, db_password);
            System.out.println("getDiariaComerFromDB() ON_CONNECT ");
            if(useByTraco)
            {
                System.out.println("getDiariaComerFromDB() TRACO = OK ");
                String razon_social = getRazonSocial(con, sess);
                sql = (new StringBuilder()).append("call ReporteProveedoresByTRACO('").append(razon_social).append("', '").append(termid).append("', '").append(dni).append("', '").append(fecha_ini).append("', '").append(fecha_fin).append("')").toString();
                sql2 = (new StringBuilder()).append("call ReporteProveedoresByCUP('").append(razon_social).append("', '").append(termid).append("', '").append(dni).append("')").toString();
                System.out.println((new StringBuilder()).append("getDiariaComerFromDB() SQL = \n ").append(sql).toString());
            } else
            {
                System.out.println("getDiariaComerFromDB() TRACO = NOK ");
                sql = (new StringBuilder()).append("call ReporteProveedoresByTRACO2('").append(comer).append("', '").append(termid).append("', '").append(dni).append("', '").append(fecha_ini).append("', '").append(fecha_fin).append("')").toString();
                sql2 = (new StringBuilder()).append("call ReporteProveedoresByCUP2('").append(comer).append("', '").append(termid).append("', '").append(dni).append("')").toString();
                System.out.println((new StringBuilder()).append("getDiariaComerFromDB() SQL = \n ").append(sql).toString());
            }
            st = (Statement)con.createStatement();
            st.execute(sql);
            ComerRepo dia;
            for(rs = (ResultSet)st.getResultSet(); rs.next(); periodo.add(dia))
            {
                System.out.println("getDiariaComerFromDB() ON_WHILE ");
                dia = new ComerRepo();
                dia.setComer_id(rs.getString("COMER_ID"));
                dia.setProd_id(rs.getString("PROD_ID"));
                dia.setTerm_date(rs.getString("TERM_DATE"));
                dia.setTerm_time(rs.getString("TERM_TIME"));
                dia.setTerm_id(rs.getString("TERM_ID"));
                dia.setAuth_code(rs.getString("AUTH_CODE"));
                dia.setLote_id(rs.getString("LOTE_ID"));
                dia.setNum_cupon(rs.getString("NUM_CUPON"));
                dia.setCantidad(rs.getString("CANTIDAD"));
                dia.setCantidad_kig(rs.getString("CANTIDAD_KIG"));
                dia.setAnulado(rs.getString("ANULADO"));
                dia.setConcepto(rs.getString("CONCEPTO"));
                dia.setNro_tarjeta(rs.getString("NRO_TARJETA"));
                dia.setApellido_nombre(rs.getString("APELLIDO_NOMBRE"));
                dia.setDni(rs.getString("DNI"));
                dia.setLocalidad(rs.getString("LOCALIDAD"));
                dia.setDomicilio(rs.getString("DOMICILIO"));
                dia.setId_trans(rs.getString("ID_TRANS"));
            }

        }
        catch(SQLException ex)
        {
            System.out.println((new StringBuilder()).append("getDiariaComerFromDB() EXCEP: ").append(ex.getMessage()).toString());
        }
        System.out.println("getDiariaComerFromDB() END ");
        return periodo;
    }

    private List getDiariaFromDB(String fecha, String per)
    {
        Connection con = null;
        Statement st = null;
        ResultSet rs = null;
        String sql = null;
        String url = "jdbc:mysql://192.168.1.1:3306/kigsolidario2";
        String user = "kigreader";
        String password = "bufa$an-";
        List periodo = new ArrayList();
        if(fecha != null)
            sql = (new StringBuilder()).append("SELECT id_carga, ciudad, barrio, fecha_tr, hora_tr, id_tr, apellido_nombre, nro_doc, periodo, prod_id, cantidad_kilo, codigo_proveedor, ubicacion_entrega, tipo_trans, anulado FROM reporte_diaria WHERE periodo = '").append(per).append("' and fecha_tr='").append(fecha).append("'").toString();
        else
            sql = (new StringBuilder()).append("SELECT id_carga, ciudad, barrio, fecha_tr, hora_tr, id_tr, apellido_nombre, nro_doc, periodo, prod_id, cantidad_kilo, codigo_proveedor, ubicacion_entrega, tipo_trans, anulado FROM reporte_diaria WHERE periodo = '").append(per).append("'").toString();
        try
        {
            con = DriverManager.getConnection(url, user, password);
            st = (Statement)con.createStatement();
            Diaria dia;
            for(rs = (ResultSet)st.executeQuery(sql); rs.next(); periodo.add(dia))
            {
                System.out.println(rs.getString(1));
                dia = new Diaria();
                dia.setId_carga(rs.getInt("id_carga"));
                dia.setCiudad(rs.getString("ciudad"));
                dia.setBarrio(rs.getString("barrio"));
                dia.setFecha_tr(rs.getString("fecha_tr"));
                dia.setHora_tr(rs.getString("hora_tr"));
                dia.setId_tr(String.format("%012d", new Object[] {
                    Integer.valueOf(dia.getId_carga())
                }));
                dia.setApellido_nombre(rs.getString("apellido_nombre"));
                dia.setNro_doc(rs.getString("nro_doc"));
                dia.setPeriodo(rs.getString("periodo"));
                dia.setProd_id(rs.getString("prod_id"));
                dia.setCantidad_kilo(rs.getDouble("cantidad_kilo"));
                dia.setCodigo_proveedor(rs.getString("codigo_proveedor"));
                dia.setUbicacion_entrega(rs.getString("ubicacion_entrega"));
                dia.setTipo_trans(rs.getString("tipo_trans"));
                dia.setAnulado(rs.getString("anulado"));
            }

        }
        catch(SQLException ex)
        {
            System.out.println((new StringBuilder()).append("EXCEP: ").append(ex.getMessage()).toString());
        }
        return periodo;
    }

    private String getRazonSocial(Connection con, String sessid)
    {
        String ret = null;
        Statement st = null;
        ResultSet rs = null;
        try
        {
            st = (Statement)con.createStatement();
            rs = (ResultSet)st.executeQuery((new StringBuilder()).append("SELECT comer.nro_cuit FROM web_sessions2 ws, web_users2 wu, sgas_comercio comer WHERE ws.session_id='").append(sessid).append("' AND ").append("ws.usr_id=wu.nombre and wu.id=comer.cod_comercio").toString());
            rs.next();
            ret = rs.getString("nro_cuit");
            rs.close();
            st.close();
        }
        catch(SQLException ex)
        {
            System.out.println((new StringBuilder()).append("getRazonSocial() EXCEP: ").append(ex.getMessage()).toString());
            ret = null;
        }
        return ret;
    }

    private String HaveUserSessID(Connection con, String usr)
    {
        String ret = null;
        Statement st = null;
        ResultSet rs = null;
        try
        {
            st = (Statement)con.createStatement();
            rs = (ResultSet)st.executeQuery((new StringBuilder()).append("SELECT session_id FROM web_sessions2 WHERE usr_id='").append(usr).append("'").toString());
            rs.next();
            ret = rs.getString("session_id");
            rs.close();
            st.close();
        }
        catch(SQLException ex)
        {
            System.out.println((new StringBuilder()).append("HaveUserSessID() EXCEP: ").append(ex.getMessage()).toString());
            ret = null;
        }
        return ret;
    }

    private String CheckSessID(Connection con, String sid)
    {
        String ret = null;
        Statement st = null;
        ResultSet rs = null;
        try
        {
            st = (Statement)con.createStatement();
            rs = (ResultSet)st.executeQuery((new StringBuilder()).append("SELECT usr_id FROM web_sessions2 WHERE session_id='").append(sid).append("'").toString());
            rs.next();
            ret = rs.getString("usr_id");
            rs.close();
            st.close();
        }
        catch(SQLException ex)
        {
            System.out.println((new StringBuilder()).append("EXCEP: ").append(ex.getMessage()).toString());
            ret = null;
        }
        return ret;
    }

    private String CheckUser(Connection con, String user, String pass)
    {
        String ret = null;
        Statement st = null;
        ResultSet rs = null;
        try
        {
            st = (Statement)con.createStatement();
            rs = (ResultSet)st.executeQuery((new StringBuilder()).append("SELECT id FROM web_users2 WHERE nombre='").append(user).append("' AND password='").append(pass).append("'").toString());
            rs.next();
            ret = rs.getString("id");
            rs.close();
            st.close();
        }
        catch(SQLException ex)
        {
            System.out.println((new StringBuilder()).append("CheckUser() EXCEP: ").append(ex.getMessage()).toString());
            ret = null;
        }
        return ret;
    }

    private int PushSessID(Connection con, String uid, String sid)
    {
        int ret = 0;
        Statement st = null;
        ResultSet rs = null;
        String sql = null;
        String sess = null;
        System.out.println((new StringBuilder()).append("PushSessID() INIT -> uid=").append(uid).append(", sid=").append(sid).toString());
        try
        {
            st = (Statement)con.createStatement();
            sess = HaveUserSessID(con, uid);
            if(sess == null)
            {
                sql = (new StringBuilder()).append("INSERT INTO web_sessions2(usr_id, session_id) VALUES('").append(uid).append("', '").append(sid).append("')").toString();
                ret = 0;
            } else
            {
                sql = (new StringBuilder()).append("UPDATE web_sessions2 set ts=CURRENT_TIMESTAMP WHERE session_id='").append(sess).append("'").toString();
                ret = 1;
            }
            st.executeUpdate(sql);
            System.out.println("Ok generado");
            st.close();
        }
        catch(SQLException ex)
        {
            System.out.println((new StringBuilder()).append("EXCEP: ").append(ex.getMessage()).toString());
            ret = -1;
        }
        System.out.println((new StringBuilder()).append("PushSessID() END -> uid=").append(uid).append(", sid=").append(sid).toString());
        System.out.println((new StringBuilder()).append("RET = ").append(ret).toString());
        return ret;
    }

    public String Login(String usr, String pass)
    {
        String sessid = null;
        String usrid = null;
        Connection conn = null;
        String url = "jdbc:mysql://192.168.1.1:3306/kigsolidario2";
        String db_user = "kigadmin2";
        String db_password = "mar89$an2-";
        try
        {
            conn = DriverManager.getConnection(url, db_user, db_password);
            usrid = CheckUser(conn, usr, pass);
            if(usrid != null)
            {
                sessid = HaveUserSessID(conn, usr);
                if(sessid == null)
                    sessid = UUID.randomUUID().toString();
                if(PushSessID(conn, usr, sessid) < 0)
                    sessid = "ERR:DB";
            } else
            {
                sessid = "ERR:USER";
            }
        }
        catch(SQLException ex)
        {
            System.out.println((new StringBuilder()).append("EXCEP: ").append(ex.getMessage()).toString());
            sessid = "ERR:DB_CONN_ERR";
        }
        return sessid;
    }

    public List getDiariaByComercio(String sessid, String comer, String termid, String dni, String fecha_ini, String fecha_fin)
    {
        System.out.println("getDiariaByComercio() INIT ");
        List dias = getDiariaComerFromDB(sessid, comer, termid, dni, fecha_ini, fecha_fin);
        System.out.println("getDiariaByComercio() END ");
        return dias;
    }

    public List getPendientesByComercio(String sessid, String comer, String termid, String dni)
    {
        System.out.println("getPendientesByComercio() INIT ");
        List dias = getVivosFromDB(sessid, comer, termid, dni);
        System.out.println("getPendientesByComercio() END ");
        return dias;
    }

    private List getDiariaByDate(String fec)
    {
        List dias = getDiariaFromDB(fec, "2015-09-01");
        return dias;
    }
}

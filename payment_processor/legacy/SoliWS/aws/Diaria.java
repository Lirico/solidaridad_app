// Decompiled by Jad v1.5.8e. Copyright 2001 Pavel Kouznetsov.
// Jad home page: http://www.geocities.com/kpdus/jad.html
// Decompiler options: packimports(3) 
// Source File Name:   Diaria.java

package aws;


public class Diaria
{

    public void setAnulado(String anulado)
    {
        this.anulado = anulado;
    }

    public void setApellido_nombre(String apellido_nombre)
    {
        this.apellido_nombre = apellido_nombre;
    }

    public void setBarrio(String barrio)
    {
        this.barrio = barrio;
    }

    public void setCantidad_kilo(double cantidad_kilo)
    {
        this.cantidad_kilo = cantidad_kilo;
    }

    public void setCiudad(String ciudad)
    {
        this.ciudad = ciudad;
    }

    public void setCodigo_proveedor(String codigo_proveedor)
    {
        this.codigo_proveedor = codigo_proveedor;
    }

    public void setFecha_tr(String fecha_tr)
    {
        this.fecha_tr = fecha_tr;
    }

    public void setHora_tr(String hora_tr)
    {
        this.hora_tr = hora_tr;
    }

    public void setId_carga(int id_carga)
    {
        this.id_carga = id_carga;
    }

    public void setId_tr(String id_tr)
    {
        this.id_tr = id_tr;
    }

    public void setNro_doc(String nro_doc)
    {
        this.nro_doc = nro_doc;
    }

    public void setPeriodo(String periodo)
    {
        this.periodo = periodo;
    }

    public void setProd_id(String prod_id)
    {
        this.prod_id = prod_id;
    }

    public void setTipo_trans(String tipo_trans)
    {
        this.tipo_trans = tipo_trans;
    }

    public void setUbicacion_entrega(String ubicacion_entrega)
    {
        this.ubicacion_entrega = ubicacion_entrega;
    }

    public String getAnulado()
    {
        return anulado;
    }

    public String getApellido_nombre()
    {
        return apellido_nombre;
    }

    public String getBarrio()
    {
        return barrio;
    }

    public double getCantidad_kilo()
    {
        return cantidad_kilo;
    }

    public String getCiudad()
    {
        return ciudad;
    }

    public String getCodigo_proveedor()
    {
        return codigo_proveedor;
    }

    public String getFecha_tr()
    {
        return fecha_tr;
    }

    public String getHora_tr()
    {
        return hora_tr;
    }

    public int getId_carga()
    {
        return id_carga;
    }

    public String getId_tr()
    {
        return id_tr;
    }

    public String getNro_doc()
    {
        return nro_doc;
    }

    public String getPeriodo()
    {
        return periodo;
    }

    public String getProd_id()
    {
        return prod_id;
    }

    public String getTipo_trans()
    {
        return tipo_trans;
    }

    public String getUbicacion_entrega()
    {
        return ubicacion_entrega;
    }

    public Diaria()
    {
    }

    private int id_carga;
    private String ciudad;
    private String barrio;
    private String fecha_tr;
    private String hora_tr;
    private String id_tr;
    private String apellido_nombre;
    private String nro_doc;
    private String periodo;
    private String prod_id;
    private double cantidad_kilo;
    private String codigo_proveedor;
    private String ubicacion_entrega;
    private String tipo_trans;
    private String anulado;
}

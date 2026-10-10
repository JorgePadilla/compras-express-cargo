# QA de PR-F2.2a · Una factura no se anula (ni se des-anula) con un UPDATE.
#
# `facturas_fiscal_inmutable` frena los datos fiscales, pero deja escribir
# `estado`, `anulada_at` y `motivo_anulacion` —los que escribe la anulación—.
# Con eso, un `UPDATE facturas SET estado = 'anulada'` dejaba la factura
# ANULADA sin documento anulado ni asiento de anulación, y el UPDATE al revés la
# «des-anulaba» después de que el libro ya la había anulado.
#
# Este trigger no mira la columna: mira **el respaldo**. Al confirmar la
# transacción (DEFERRABLE INITIALLY DEFERRED, porque la gema guarda la factura
# antes que su documento y su asiento), cada factura tocada tiene que tener:
#
# - su documento fiscal (`documentos_fiscales`, el mismo número, ella como
#   `documentable`) en el **mismo** estado;
# - el asiento de emisión en el libro;
# - asiento de anulación **si y solo si** está anulada. El libro no se borra
#   (`asientos_fiscales_solo_agregar`), así que una vez anulada en el libro no
#   vuelve a estar emitida.
#
# Lee la fila como está al confirmar, no como la dejó cada sentencia: una
# factura que se emite y se anula en la misma transacción se mira una vez, ya
# anulada.
class FacturasRespaldoFiscal < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE FUNCTION public.facturas_respaldo_fiscal() RETURNS trigger
        LANGUAGE plpgsql AS $$
      DECLARE
        f public.facturas%ROWTYPE;
        anulada_en_el_libro boolean;
      BEGIN
        SELECT * INTO f FROM public.facturas WHERE id = NEW.id;
        IF NOT FOUND THEN
          RETURN NULL;
        END IF;

        IF NOT EXISTS (
          SELECT 1 FROM public.documentos_fiscales d
           WHERE d.numero = f.numero AND d.documentable_type = 'Factura'
             AND d.documentable_id = f.id AND d.estado = f.estado
        ) THEN
          RAISE EXCEPTION 'la factura % no tiene su documento fiscal en estado %', f.numero, f.estado
            USING ERRCODE = 'restrict_violation';
        END IF;

        IF NOT EXISTS (
          SELECT 1 FROM public.asientos_fiscales a WHERE a.numero = f.numero AND a.evento = 'emision'
        ) THEN
          RAISE EXCEPTION 'la factura % no tiene su asiento de emisión en el libro', f.numero
            USING ERRCODE = 'restrict_violation';
        END IF;

        anulada_en_el_libro := EXISTS (
          SELECT 1 FROM public.asientos_fiscales a WHERE a.numero = f.numero AND a.evento = 'anulacion'
        );
        IF (f.estado = 'anulada') IS DISTINCT FROM anulada_en_el_libro THEN
          RAISE EXCEPTION 'la factura % dice %, y el libro dice otra cosa', f.numero, f.estado
            USING ERRCODE = 'restrict_violation';
        END IF;

        RETURN NULL;
      END
      $$;

      CREATE CONSTRAINT TRIGGER facturas_respaldo_fiscal
        AFTER INSERT OR UPDATE ON public.facturas
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION public.facturas_respaldo_fiscal();
    SQL
  end

  def down
    execute "DROP FUNCTION public.facturas_respaldo_fiscal() CASCADE"
  end
end

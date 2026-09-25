package lab.migracao;

import org.hibernate.SessionFactory;

public class LimpezaCache {
    public void limpar(SessionFactory factory) {
        factory.getCache().evictDefaultQueryRegion();
    }
}

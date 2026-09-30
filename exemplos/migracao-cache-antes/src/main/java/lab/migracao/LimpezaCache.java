package lab.migracao;

import org.hibernate.Cache;
import org.hibernate.SessionFactory;

public class LimpezaCache {
    public void limpar(SessionFactory factory) {
        if (factory == null || factory.isClosed()) {
            return;
        }

        Cache cache = factory.getCache();
        if (cache != null) {
            cache.evictDefaultQueryRegion();
        }
    }
}

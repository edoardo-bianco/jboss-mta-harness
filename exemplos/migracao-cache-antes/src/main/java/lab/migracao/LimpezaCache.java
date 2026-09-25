package lab.migracao;

import org.hibernate.SessionFactory;
import org.hibernate.cache.spi.QueryCache;
import org.hibernate.engine.spi.SessionFactoryImplementor;

public class LimpezaCache {
    public void limpar(SessionFactory factory) {
        SessionFactoryImplementor factoryInterna = (SessionFactoryImplementor) factory;
        QueryCache cache = factoryInterna.getQueryCache();
        if (cache != null) {
            cache.clear();
        }
    }
}

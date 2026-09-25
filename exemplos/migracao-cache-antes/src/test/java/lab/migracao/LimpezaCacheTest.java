package lab.migracao;

import org.hibernate.Session;
import org.hibernate.SessionFactory;
import org.hibernate.Transaction;
import org.hibernate.cfg.Configuration;
import org.junit.Test;

import static org.junit.Assert.assertEquals;

public class LimpezaCacheTest {
    static SessionFactory abrirFactory(boolean cacheAtivo) {
        return new Configuration()
                .setProperty("hibernate.dialect", "org.hibernate.dialect.H2Dialect")
                .setProperty("hibernate.connection.driver_class", "org.h2.Driver")
                .setProperty("hibernate.connection.url", "jdbc:h2:mem:cache_demo")
                .setProperty("hibernate.cache.use_query_cache", Boolean.toString(cacheAtivo))
                .setProperty("hibernate.cache.region.factory_class", "org.hibernate.cache.ehcache.EhCacheRegionFactory")
                .setProperty("hibernate.generate_statistics", "true")
                .buildSessionFactory();
    }

    private void consultar(SessionFactory factory, String regiao) {
        try (Session session = factory.openSession()) {
            Transaction transaction = session.beginTransaction();
            org.hibernate.SQLQuery query = session.createSQLQuery("select 42 as valor");
            query.addScalar("valor", org.hibernate.type.StandardBasicTypes.INTEGER);
            query.setCacheable(true);
            if (regiao != null) {
                query.setCacheRegion(regiao);
            }
            assertEquals(42, ((Number) query.uniqueResult()).intValue());
            transaction.commit();
        }
    }

    @Test
    public void invalidaConsultasPadraoPreservandoOutrasRegioes() {
        try (SessionFactory factory = abrirFactory(true)) {
            consultar(factory, null);
            consultar(factory, "outra-regiao");
            factory.getStatistics().clear();
            consultar(factory, null);
            consultar(factory, "outra-regiao");
            assertEquals(2, factory.getStatistics().getQueryCacheHitCount());

            new LimpezaCache().limpar(factory);

            factory.getStatistics().clear();
            consultar(factory, null);
            consultar(factory, "outra-regiao");
            assertEquals(1, factory.getStatistics().getQueryCacheMissCount());
            assertEquals(1, factory.getStatistics().getQueryCacheHitCount());
        }
    }

    @Test
    public void aceitaCacheDesativado() {
        try (SessionFactory factory = abrirFactory(false)) {
            new LimpezaCache().limpar(factory);
            consultar(factory, null);
            assertEquals(0, factory.getStatistics().getQueryCachePutCount());
        }
    }
}

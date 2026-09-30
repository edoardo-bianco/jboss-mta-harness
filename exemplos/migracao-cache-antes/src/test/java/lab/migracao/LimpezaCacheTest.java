package lab.migracao;

import java.lang.reflect.Proxy;
import org.hibernate.Session;
import org.hibernate.SessionFactory;
import org.hibernate.Transaction;
import org.hibernate.cfg.Configuration;
import org.junit.Test;

import static org.junit.Assert.assertEquals;

public class LimpezaCacheTest {
    @Test
    public void aceitaFactoryAusente() {
        new LimpezaCache().limpar(null);
    }

    @Test
    public void naoAcessaCacheDeFactoryFechada() {
        SessionFactory factory = (SessionFactory) Proxy.newProxyInstance(
                getClass().getClassLoader(), new Class<?>[]{SessionFactory.class},
                (proxy, method, args) -> {
                    if ("isClosed".equals(method.getName())) {
                        return true;
                    }
                    throw new AssertionError("Factory fechada nao deve ser acessada: " + method.getName());
                });

        new LimpezaCache().limpar(factory);
    }

    @Test
    public void aceitaFactorySemCache() {
        SessionFactory factory = (SessionFactory) Proxy.newProxyInstance(
                getClass().getClassLoader(), new Class<?>[]{SessionFactory.class},
                (proxy, method, args) -> {
                    if ("isClosed".equals(method.getName())) {
                        return false;
                    }
                    if ("getCache".equals(method.getName())) {
                        return null;
                    }
                    throw new AssertionError("Acesso inesperado: " + method.getName());
                });

        new LimpezaCache().limpar(factory);
    }

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
    public void ignoraFactoryNula() {
        new LimpezaCache().limpar(null);
    }

    @Test
    public void ignoraFactoryFechada() {
        SessionFactory factory = abrirFactory(true);
        factory.close();

        new LimpezaCache().limpar(factory);
        assertEquals(true, factory.isClosed());
    }

    @Test
    public void ignoraCacheIndisponivel() {
        SessionFactory factory = new Configuration()
                .setProperty("hibernate.dialect", "org.hibernate.dialect.H2Dialect")
                .setProperty("hibernate.connection.driver_class", "org.h2.Driver")
                .setProperty("hibernate.connection.url", "jdbc:h2:mem:cache_demo_sem_cache")
                .setProperty("hibernate.cache.use_second_level_cache", "false")
                .setProperty("hibernate.cache.use_query_cache", "false")
                .setProperty("hibernate.generate_statistics", "true")
                .buildSessionFactory();

        try {
            new LimpezaCache().limpar(factory);
        } finally {
            factory.close();
        }
    }

    @Test
    public void invalidaConsultasPadraoPreservandoOutrasRegioes() {
        try (SessionFactory factory = abrirFactory(true)) {
            consultar(factory, null);
            consultar(factory, "outra-regiao");

            new LimpezaCache().limpar(factory);

            factory.getStatistics().clear();
            consultar(factory, null);
            assertEquals(1, factory.getStatistics().getQueryCacheMissCount());
            assertEquals(0, factory.getStatistics().getQueryCacheHitCount());

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

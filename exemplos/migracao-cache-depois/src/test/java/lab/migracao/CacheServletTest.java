package lab.migracao;

import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.Field;
import java.lang.reflect.Proxy;
import java.util.HashMap;
import java.util.Map;
import javax.persistence.EntityManagerFactory;
import javax.servlet.http.HttpServletResponse;
import org.hibernate.SessionFactory;
import org.junit.Test;

import static org.junit.Assert.assertEquals;

public class CacheServletTest {
    @Test
    public void respondeComContratoDaOperacaoDeLimpeza() throws Exception {
        try (SessionFactory factory = LimpezaCacheTest.abrirFactory(true)) {
            EntityManagerFactory persistence = (EntityManagerFactory) Proxy.newProxyInstance(
                    getClass().getClassLoader(), new Class<?>[]{EntityManagerFactory.class},
                    (proxy, method, args) -> {
                        if ("unwrap".equals(method.getName())) {
                            return factory;
                        }
                        throw new UnsupportedOperationException(method.getName());
                    });
            CacheServlet servlet = new CacheServlet();
            Field injection = CacheServlet.class.getDeclaredField("entityManagerFactory");
            injection.setAccessible(true);
            injection.set(servlet, persistence);
            StringWriter body = new StringWriter();
            Map<String, Object> responseValues = new HashMap<>();
            HttpServletResponse response = (HttpServletResponse) Proxy.newProxyInstance(
                    getClass().getClassLoader(), new Class<?>[]{HttpServletResponse.class},
                    (proxy, method, args) -> {
                        if ("getWriter".equals(method.getName())) {
                            return new PrintWriter(body);
                        }
                        responseValues.put(method.getName(), args[0]);
                        return null;
                    });

            servlet.doPost(null, response);

            assertEquals(200, responseValues.get("setStatus"));
            assertEquals("text/plain", responseValues.get("setContentType"));
            assertEquals("UTF-8", responseValues.get("setCharacterEncoding"));
            assertEquals("CACHE_CONSULTAS_LIMPO", body.toString());
        }
    }
}

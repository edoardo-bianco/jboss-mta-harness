package lab.migracao;

import java.io.IOException;
import javax.persistence.EntityManagerFactory;
import javax.persistence.PersistenceUnit;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import org.hibernate.SessionFactory;

@WebServlet("/cache/limpar")
public class CacheServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    @PersistenceUnit(unitName = "demo")
    private transient EntityManagerFactory entityManagerFactory;

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException {
        new LimpezaCache().limpar(entityManagerFactory.unwrap(SessionFactory.class));
        response.setStatus(HttpServletResponse.SC_OK);
        response.setContentType("text/plain");
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write("CACHE_CONSULTAS_LIMPO");
    }
}

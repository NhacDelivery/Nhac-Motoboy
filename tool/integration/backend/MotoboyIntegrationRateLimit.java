package br.com.nhac.backend_nhac.config;

import br.com.nhac.backend_nhac.domain.auth.AuthRateLimitService;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/** Mantém o limite real de autenticação, com uma janela independente por cenário. */
@Component
@Primary
@Profile("motoboy-integration")
public class MotoboyIntegrationRateLimit extends AuthRateLimitService {
    private volatile AuthRateLimitService cenario = new AuthRateLimitService();

    void iniciarCenario() {
        cenario = new AuthRateLimitService();
    }

    @Override
    public void checar(String identificador) {
        cenario.checar(identificador);
    }
}

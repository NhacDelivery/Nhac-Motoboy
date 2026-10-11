package br.com.nhac.backend_nhac.config;

import br.com.nhac.backend_nhac.domain.entregador.*;
import br.com.nhac.backend_nhac.domain.loja.*;
import br.com.nhac.backend_nhac.domain.pedido.*;
import br.com.nhac.backend_nhac.domain.usuario.*;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;

/** Compilada somente no runner de integração; nunca entra no JAR de produção. */
@Component
@Profile("motoboy-integration")
public class MotoboyIntegrationFixture implements CommandLineRunner {
    private final UsuarioRepository usuarios;
    private final EntregadorRepository entregadores;
    private final LojaRepository lojas;
    private final PedidoRepository pedidos;
    private final PasswordEncoder encoder;

    public MotoboyIntegrationFixture(UsuarioRepository usuarios, EntregadorRepository entregadores,
            LojaRepository lojas, PedidoRepository pedidos, PasswordEncoder encoder) {
        this.usuarios = usuarios;
        this.entregadores = entregadores;
        this.lojas = lojas;
        this.pedidos = pedidos;
        this.encoder = encoder;
    }

    @Override
    public void run(String... args) {
        Usuario cliente = usuario("cliente", Papel.CLIENTE);
        Usuario lojista = usuario("lojista", Papel.LOJISTA);
        usuario("motoboy", Papel.CLIENTE);
        usuario("bloqueio", Papel.CLIENTE);
        usuario("outro", Papel.CLIENTE);
        usuario("integracao-admin", Papel.ADMIN);

        DadosOperacionais operacao = new DadosOperacionais();
        operacao.setTaxaEntregaBase(new BigDecimal("5.00"));
        operacao.setEntregaPropria(false);
        operacao.setRaioEntregaKm(new BigDecimal("20.00"));
        Loja loja = Loja.builder().id("it-loja").usuarioId(lojista.getId())
                .nome("Loja integração").isAberto(true).dadosOperacionais(operacao)
                .geoLocalizacao(new GeoLocalizacao(-23.550520, -46.633308, "6gyf4"))
                .endereco(new EnderecoLoja("Praça da Sé", "1", "São Paulo", "SP", "01001-000", "Sé", "Teste"))
                .build();
        lojas.saveAndFlush(loja);
        pedido("it-pedido", cliente, loja);
        pedido("it-bloqueio", cliente, loja);
        // Os cadastros de entregador e as ofertas são criados pelos endpoints reais nos testes.
        System.out.println("MOTOBOY_INTEGRATION_FIXTURE_READY");
    }

    Usuario usuario(String nome, Papel papel) {
        Usuario u = new Usuario();
        u.setId("it-" + nome);
        u.setNome("Integração " + nome);
        u.setEmail(nome + "@integration.nhac.local");
        u.setTelefone(String.format("+55119999%05d",Math.abs(nome.hashCode()%100000)));
        u.setSenha(encoder.encode("NhacIntegration#123"));
        u.setPapel(papel);
        u.setAtivo(true);
        u.setEmailVerificado(true);
        u.setTelefoneVerificado(true);
        u.setEnderecos(new ArrayList<>());
        return usuarios.saveAndFlush(u);
    }

    void pedido(String id, Usuario cliente, Loja loja) {
        Pedido p = new Pedido();
        p.setId(id);
        p.setUsuarioId(cliente.getId());
        p.setLoja(loja);
        p.setStatus(StatusPedido.PREPARANDO);
        p.setValorTotal(new BigDecimal("30.00"));
        p.setTaxaFrete(new BigDecimal("5.00"));
        p.setDesconto(BigDecimal.ZERO);
        p.setFormaPagamento("DINHEIRO");
        p.setCriadoEm(Instant.now());
        p.setEnderecoEntrega(new EnderecoEntrega("Praça da Sé", "100", "Sé", "São Paulo", "SP", "01001-000", "Teste"));
        p.setEntregaLatitude(-23.551000);
        p.setEntregaLongitude(-46.634000);
        p.setCodigoEntrega("0123");
        pedidos.saveAndFlush(p);
    }
}

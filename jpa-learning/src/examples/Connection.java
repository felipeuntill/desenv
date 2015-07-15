package examples;

import javax.persistence.EntityManager;
import javax.persistence.EntityManagerFactory;
import javax.persistence.EntityTransaction;
import javax.persistence.Persistence;

public class Connection {

	public static void main(String[] args) {
		
		EntityManagerFactory factory = Persistence.createEntityManagerFactory("jpa-learning");
		EntityManager manager = factory.createEntityManager();
		
		
	/*	
		Server server = new Server();
		server.setDescricao("li317.portoseguro.brasil");
		server.setTipo("WebSphere");
		
		EntityTransaction tx = manager.getTransaction();
		tx.begin();
		
		manager.persist(server);
		
		tx.commit();*/
		
		Server server1 = manager.find(Server.class, 1L);
		manager.clear();
		Server server2 = manager.find(Server.class, 1L);
		
		System.out.println(server1.getDescricao());
		
		
		factory.close();

	}

}

import java.io.FileInputStream;
import java.security.KeyStore;
import java.util.Enumeration;

public class JceksVerifier {
    public static void main(String[] args) {
        if (args.length < 2) {
            System.err.println("Usage: java JceksVerifier <jceks_file> <password>");
            System.exit(1);
        }

        String fileName = args[0];
        char[] password = args[1].toCharArray();

        try {
            KeyStore ks = KeyStore.getInstance("JCEKS");
            FileInputStream fis = new FileInputStream(fileName);
            ks.load(fis, password);
            fis.close();
            
            System.out.println("JCEKS Loaded Successfully");
            System.out.println("Size: " + ks.size());
            
            Enumeration<String> aliases = ks.aliases();
            while (aliases.hasMoreElements()) {
                String alias = aliases.nextElement();
                 if (ks.isKeyEntry(alias)) {
                     try {
                        ks.getKey(alias, password);
                     } catch (Exception e) {
                        System.err.println("Failed to recover key for alias: " + alias);
                        e.printStackTrace();
                        System.exit(2);
                     }
                }
            }
            System.out.println("Verification Complete");
            
        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        }
    }
}

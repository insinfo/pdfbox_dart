
import java.io.FileInputStream;
import java.security.KeyStore;
import java.util.Enumeration;

public class JksVerifier {
    public static void main(String[] args) {
        if (args.length < 2) {
            System.err.println("Usage: java JksVerifier <jks_file> <password>");
            System.exit(1);
        }

        String fileName = args[0];
        char[] password = args[1].toCharArray();

        try {
            KeyStore ks = KeyStore.getInstance("JKS");
            FileInputStream fis = new FileInputStream(fileName);
            ks.load(fis, password);
            fis.close();
            
            System.out.println("JKS Loaded Successfully");
            System.out.println("Size: " + ks.size());
            
            Enumeration<String> aliases = ks.aliases();
            while (aliases.hasMoreElements()) {
                String alias = aliases.nextElement();
                // Just touching the entry to ensure it's valid
                if (ks.isKeyEntry(alias)) {
                     // Try to recover key (decrypts it)
                     try {
                        ks.getKey(alias, password);
                     } catch (Exception e) {
                        System.err.println("Failed to recover key for alias: " + alias);
                        e.printStackTrace();
                        System.exit(2);
                     }
                }
                // Certificate checks are implicit in load/aliases for structure
            }
            System.out.println("Verification Complete");
            
        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        }
    }
}

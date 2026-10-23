@IsTest
private class WinbackCouponIssuerTest {
    private static Contact createCustomer(String lastName, Date lastVisit) {
        Account acc = new Account(Name = '個人のお客様（テスト）');
        insert acc;
        Contact c = new Contact(AccountId = acc.Id, LastName = lastName, Email = 'test@example.com');
        insert c;
        insert new PointHistory__c(Contact__c = c.Id, Type__c = '付与', Store__c = '渋谷店', PurchaseAmount__c = 1500, TransactionDate__c = lastVisit);
        return c;
    }

    @IsTest
    static void issuesCouponToDormantCustomer() {
        Contact c = createCustomer('休眠', Date.today().addDays(-61));

        Test.startTest();
        List<Coupon__c> issued = WinbackCouponIssuer.issue();
        Test.stopTest();

        System.assertEquals(1, issued.size());
        Coupon__c coupon = [SELECT Content__c, IssueDate__c, ExpirationDate__c, NotificationMethod__c FROM Coupon__c WHERE Contact__c = :c.Id];
        System.assertEquals(WinbackCouponIssuer.CONTENT, coupon.Content__c);
        System.assertEquals(Date.today().addDays(30), coupon.ExpirationDate__c);
        System.assertEquals('メール', coupon.NotificationMethod__c);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhoId = :c.Id]);
    }

    @IsTest
    static void doesNotIssueTwiceInSameDormantPeriod() {
        Contact c = createCustomer('二重発行なし', Date.today().addDays(-70));
        WinbackCouponIssuer.issue();

        Test.startTest();
        List<Coupon__c> issued = WinbackCouponIssuer.issue();
        Test.stopTest();

        System.assertEquals(0, issued.size());
        System.assertEquals(1, [SELECT COUNT() FROM Coupon__c WHERE Contact__c = :c.Id]);
    }

    @IsTest
    static void skipsRecentCustomer() {
        createCustomer('最近来店', Date.today().addDays(-10));

        Test.startTest();
        System.schedule('WinbackCouponIssuerTest', '0 0 6 * * ?', new WinbackCouponIssuer());
        List<Coupon__c> issued = WinbackCouponIssuer.issue();
        Test.stopTest();

        System.assertEquals(0, issued.size());
    }
}

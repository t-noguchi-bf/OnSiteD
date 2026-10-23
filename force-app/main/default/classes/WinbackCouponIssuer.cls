/**
 * 最終来店日から60日以上たったお客様に「次回お会計時10%オフ」のクーポンを発行する。
 * 毎日1回スケジュール実行する。同じ休眠期間（前回の発行より後に来店していない）には二重発行しない。
 */
public with sharing class WinbackCouponIssuer implements Schedulable {
    public static final Integer DORMANT_DAYS = 60;
    public static final String CONTENT = '次回お会計時10%オフ（60日以上ご来店のないお客様へ）';

    public void execute(SchedulableContext context) {
        issue();
    }

    public static List<Coupon__c> issue() {
        Date today = Date.today();
        Date cutoff = today.addDays(-DORMANT_DAYS);
        List<Contact> targets = new List<Contact>();
        for (Contact c : [
            SELECT Id, Name, Email, LastVisitDate__c, LastWinbackCouponDate__c
            FROM Contact
            WHERE LastVisitDate__c != null AND LastVisitDate__c <= :cutoff
        ]) {
            if (c.LastWinbackCouponDate__c == null || c.LastWinbackCouponDate__c < c.LastVisitDate__c) {
                targets.add(c);
            }
        }
        if (targets.isEmpty()) {
            return new List<Coupon__c>();
        }

        List<Coupon__c> coupons = new List<Coupon__c>();
        for (Contact c : targets) {
            Boolean hasEmail = String.isNotBlank(c.Email);
            coupons.add(new Coupon__c(
                Contact__c = c.Id,
                Content__c = CONTENT,
                IssueDate__c = today,
                NotificationMethod__c = hasEmail ? 'メール' : '店頭で手渡し',
                NotifiedDate__c = hasEmail ? today : null
            ));
            c.LastWinbackCouponDate__c = today;
        }
        insert coupons;
        update targets;

        // 発行したことをお客様の活動履歴に残す
        List<Task> logs = new List<Task>();
        for (Integer i = 0; i < targets.size(); i++) {
            Contact c = targets[i];
            Boolean hasEmail = String.isNotBlank(c.Email);
            logs.add(new Task(
                WhoId = c.Id,
                Subject = '【クーポン発行】' + CONTENT,
                Description = '最終来店日：' + c.LastVisitDate__c.format() + '\n有効期限：発行日から30日、どの店舗でも1回限り\n連絡方法：'
                    + (hasEmail ? 'メールで案内' : '次回来店時に店頭で手渡し'),
                ActivityDate = today,
                Status = 'Completed'
            ));
        }
        insert logs;
        return coupons;
    }
}
